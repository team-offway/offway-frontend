import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/device_id.dart';

final liveActivityRepositoryProvider = Provider<LiveActivityRepository>(
  (ref) => LiveActivityRepository(
    ref.watch(dioProvider),
    ref.watch(deviceIdStorageProvider),
  ),
);

/// 잠금화면 카드의 갱신 토큰 등록 (`/api/v1/live-activities`, core #577).
///
/// 서버가 **매일 자정에** 이 토큰으로 카드의 D-day 를 갱신한다. 앱이 꺼져
/// 있어도 `D-3` 이 `D-2` 로 바뀌는 것은 이 등록 덕이다.
///
/// **기기 토큰(`/api/v1/devices`)과 다른 값이다.** 저쪽은 기기 하나를 가리키고
/// 앱을 지울 때까지 살지만, 이 토큰은 잠금화면에 띄운 **카드 하나**를 가리키고
/// 그 카드가 사라지면 함께 죽는다.
class LiveActivityRepository {
  LiveActivityRepository(this._dio, this._deviceId);

  final Dio _dio;

  /// 이 기기를 가리키는 값 — **두 등록이 같은 것을 실어야** 서버가 갱신
  /// 토큰과 띄우기 토큰을 한 기기로 묶는다(core #587). 안 실으면 기기 둘인
  /// 사용자의 둘째 기기에 카드가 영영 안 뜬다
  final DeviceIdStorage _deviceId;

  /// 카드의 토큰을 등록하거나 갱신한다.
  ///
  /// **몇 번을 보내도 결과가 같다** — 서버가 (사용자, 코스)로 한 행만 두고
  /// 토큰만 갈아 끼운다. iOS 가 토큰을 갱신해 줘도, 네트워크가 끊겨 성공
  /// 여부가 애매해도 그냥 다시 보내면 된다.
  ///
  /// 코스 id 는 앱이 문자열로 들고 있지만 서버는 숫자다 — 여기서 바꾼다.
  /// 숫자가 아니면 등록할 수 없는 값이라 [ArgumentError] 다
  Future<void> register({
    required String courseId,
    required String token,
  }) async {
    final id = int.tryParse(courseId);
    if (id == null) {
      throw ArgumentError.value(courseId, 'courseId', '서버 코스 id 는 숫자다');
    }
    return ApiEnvelope.guard(() async {
      final response = await _dio.post<dynamic>(
        '/api/v1/live-activities',
        // 기기 id 는 **띄우기 토큰 등록과 같은 값**이어야 한다 — 서버가 그걸로
        // 둘을 한 기기로 묶는다(core #587)
        data: {
          'courseId': id,
          'pushToken': token,
          'deviceId': await _deviceId.get(),
        },
      );
      // 공통 래퍼는 200에도 실패 code를 담을 수 있다 — 그것까지 걸러야
      // '등록됐다'가 사실이 된다
      ApiEnvelope.unwrap(response);
    });
  }

  /// 이 **기기**의 push-to-start 토큰을 등록한다 (core #585).
  ///
  /// 서버가 이 토큰으로 카드를 **처음** 띄운다 — 앱을 안 열어도 출발 5일
  /// 전부터 잠금화면에 뜬다. [register] 의 카드 토큰과 다른 값이다: 저쪽은
  /// 이미 떠 있는 카드 하나를 가리키고 카드가 죽으면 함께 죽지만, 이건 기기를
  /// 가리키고 앱을 지울 때까지 산다.
  ///
  /// **몇 번을 보내도 결과가 같다** — 서버가 (사용자, 토큰)으로 한 행만 둔다.
  /// 앱을 켤 때마다 같은 토큰이 오므로 매번 보내도 된다
  Future<void> registerPushToStart(String token) async {
    return ApiEnvelope.guard(() async {
      final response = await _dio.put<dynamic>(
        '/api/v1/live-activities/push-to-start',
        data: {'token': token, 'deviceId': await _deviceId.get()},
      );
      ApiEnvelope.unwrap(response);
    });
  }

  /// 이 기기의 push-to-start 등록을 지운다 — 로그아웃.
  ///
  /// **토큰을 본문에 담는다.** 경로에 실으면 프록시 접근 로그에 남는데, 이
  /// 값을 아는 쪽은 그 기기 잠금화면에 카드를 만들 수 있어 비밀값에 준한다
  /// (core #585).
  ///
  /// [token] 을 주면 **그 기기만**, 비우면 이 사용자의 모든 기기가 풀린다.
  /// 로그아웃은 기기별로 갈리므로(`refreshToken` 을 보낸다) 이 기기 토큰을
  /// 준다 — 전부 풀면 폰에서 로그아웃한 사용자의 태블릿 잠금화면이 같이 빈다
  Future<void> unregisterPushToStart({String? token}) async {
    return ApiEnvelope.guard(() async {
      final response = await _dio.delete<dynamic>(
        '/api/v1/live-activities/push-to-start',
        // 토큰을 모르면 본문을 비운다 — 서버가 '이 사용자 전부' 로 받는다.
        // 로그아웃인데 아무것도 못 지우는 것보다는 낫다
        data: token == null ? null : {'token': token},
      );
      ApiEnvelope.unwrap(response);
    });
  }

  /// 이 코스의 등록을 지운다 — 카드를 내렸을 때.
  ///
  /// **안 불러도 결국 정리된다.** 여행이 끝나면 자정 배치가 지우고, 토큰이
  /// 죽으면 발송이 410 을 받아 지운다. 이 호출은 그보다 빨리 치우는 것이라
  /// 실패해도 앱이 하던 일을 막을 이유가 없다 — 부르는 쪽이 삼킨다.
  ///
  /// 지울 것이 없어도 성공(200)이다
  Future<void> unregister(String courseId) async {
    final id = int.tryParse(courseId);
    if (id == null) return; // 등록된 적이 없는 값이다 — 지울 것도 없다
    return ApiEnvelope.guard(() async {
      final response = await _dio.delete<dynamic>(
        '/api/v1/live-activities/$id',
      );
      ApiEnvelope.unwrap(response);
    });
  }
}
