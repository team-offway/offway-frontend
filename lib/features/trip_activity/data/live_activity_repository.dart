import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final liveActivityRepositoryProvider = Provider<LiveActivityRepository>(
  (ref) => LiveActivityRepository(ref.watch(dioProvider)),
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
  LiveActivityRepository(this._dio);

  final Dio _dio;

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
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/live-activities',
        data: {'courseId': id, 'pushToken': token},
      );
      // 공통 래퍼는 200에도 실패 code를 담을 수 있다 — 그것까지 걸러야
      // '등록됐다'가 사실이 된다
      ApiEnvelope.unwrap(response);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
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
    try {
      final response = await _dio.delete<dynamic>(
        '/api/v1/live-activities/$id',
      );
      ApiEnvelope.unwrap(response);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}
