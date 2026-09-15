import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/trip_countdown.dart';

/// 네이티브가 카드의 푸시 토큰을 받았다 — 카드 하나마다 토큰이 따로다
typedef PushTokenListener = void Function(String courseId, String token);

/// 잠금화면·다이나믹 아일랜드(Live Activity)를 여닫는 다리.
///
/// **UI는 Swift가 그린다.** Flutter 위젯으로는 잠금화면을 그릴 수 없어,
/// 재료만 네이티브로 넘기고 화면은 Widget Extension(SwiftUI)이 맡는다.
///
/// iOS 16.1+ 에서만 동작한다. 그 아래거나 안드로이드면 **조용히 아무 일도
/// 하지 않는다** — 쓰는 쪽이 플랫폼을 검사하지 않게 여기서 삼킨다.
class TripActivityService {
  TripActivityService({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting bool? isSupportedPlatform,
  }) : _channel = channel ?? const MethodChannel(channelName),
       // 테스트는 macOS VM 에서 돈다 — Platform.isIOS 를 그대로 보면
       // 모든 호출이 조용히 빠져나가 채널 계약을 잴 수 없다
       _isSupportedPlatform = isSupportedPlatform ?? Platform.isIOS;

  /// 네이티브와 약속한 이름 — AppDelegate 가 같은 문자열을 쓴다
  static const channelName = 'com.nth.offway/trip_activity';

  final MethodChannel _channel;

  /// iOS 에서만 Live Activity 가 있다. 아니면 조용히 아무 일도 하지 않는다
  final bool _isSupportedPlatform;

  /// 이 기기에서 Live Activity 를 띄울 수 있는가.
  ///
  /// iOS 16.1 미만·안드로이드·사용자가 설정에서 껐을 때 모두 거짓이다.
  /// 판정은 네이티브가 한다 — `ActivityAuthorizationInfo` 를 Dart 에서
  /// 볼 수 없다
  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    try {
      return await _channel
              .invokeMethod<bool>('isAvailable')
              .timeout(_timeout) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Live Activity 가능 여부를 묻지 못했다: ${e.message}');
      return false;
    } on MissingPluginException {
      // 네이티브가 아직 안 붙은 빌드 — 기능이 없는 것이지 오류가 아니다
      return false;
    } on TimeoutException {
      debugPrint('Live Activity 가능 여부가 제때 오지 않았다');
      return false;
    }
  }

  /// 이 여행으로 잠금화면을 띄운다. 이미 떠 있으면 값만 갈아 끼운다.
  ///
  /// **문구가 아니라 재료를 넘긴다**(core #577 B안). 조립은 네이티브
  /// `ContentState` 가 한다 — 서버가 자정에 보내는 것과 같은 다섯 칸이라
  /// 앱이 띄운 카드와 서버가 갱신한 카드가 다른 말을 하지 않고, 카피를
  /// 바꿀 때 서버를 고칠 일이 없다.
  ///
  /// 성공 여부를 돌려준다 — 타임아웃이 나면 **띄운 건지 아닌지 알 수 없다**.
  /// 그때는 거짓이다(다음 기회에 다시 맞춘다)
  Future<bool> start(TripCountdown trip, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    return _invokeOk('start', {
      'courseId': trip.courseId,
      'regionName': trip.regionName,
      // 둘 중 하나만 값이 있다. null 도 그대로 보낸다 — 비어 있다는 것
      // 자체가 뜻이라(출발 전이냐 여행 중이냐), 빼면 네이티브가 직전
      // 값을 그대로 쓴다
      'daysLeft': trip.daysLeft(at),
      'dayNth': trip.dayNth(at),
      'startDate': TripCountdown.isoDate(trip.startDate),
      'endDate': TripCountdown.isoDate(trip.endDate),
    });
  }

  /// 떠 있는 잠금화면을 내린다 — 여행이 끝났거나 코스를 지웠을 때.
  ///
  /// **성공 여부를 돌려준다.** 로그아웃·탈퇴·세션 만료가 이걸 부르는데,
  /// 실패를 삼키면 앞사람의 여행지·날짜가 잠금화면에 남은 채로 로그인
  /// 화면으로 넘어간다 — 부르는 쪽이 알아야 다시 시도하든 알리든 한다
  Future<bool> end() => _invokeOk('end', const {});

  /// 네이티브가 카드의 푸시 토큰을 올려 보내면 받는다.
  ///
  /// 서버 등록은 JWT 를 쥔 Dart 가 한다(`LiveActivityRepository`). iOS 는
  /// 카드를 띄운 직후 첫 토큰을 주고, 도중에 갈아 끼우면 또 준다 — 그때마다
  /// 같은 등록을 다시 보내면 된다(서버가 (사용자, 코스)로 한 행만 둔다)
  void listenPushToken(PushTokenListener listener) {
    if (!_isSupportedPlatform) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onPushToken') {
        throw MissingPluginException('${call.method} 은 받지 않는다');
      }
      final args = (call.arguments as Map?)?.cast<String, Object?>();
      final courseId = args?['courseId'] as String?;
      final token = args?['token'] as String?;
      if (courseId == null || token == null || token.isEmpty) return;
      listener(courseId, token);
    });
  }

  /// 네이티브가 답하지 않을 때 기다리는 한도.
  ///
  /// ActivityKit 이 매달리면 `invokeMethod` 의 Future 가 영영 완결되지
  /// 않는다 — 앱 재개마다 부르는 자리라 그대로 쌓인다
  static const _timeout = Duration(seconds: 5);

  /// 네이티브를 부르고 **해냈는지**를 돌려준다.
  ///
  /// 던지지는 않는다 — 잠금화면 때문에 로그아웃이 막히면 안 된다. 대신
  /// 실패를 거짓으로 알려, 부르는 쪽이 판단하게 둔다
  Future<bool> _invokeOk(String method, Map<String, Object?> args) async {
    // 안 되는 플랫폼은 '실패'가 아니다 — 내릴 것이 애초에 없다
    if (!_isSupportedPlatform) return true;
    try {
      await _channel.invokeMethod<void>(method, args).timeout(_timeout);
      return true;
    } on PlatformException catch (e) {
      debugPrint('Live Activity $method 실패: ${e.message}');
      return false;
    } on MissingPluginException {
      // 네이티브가 없는 빌드 — 띄운 적이 없으니 남을 것도 없다
      debugPrint('Live Activity 네이티브가 없는 빌드다 ($method)');
      return true;
    } on TimeoutException {
      // **뜬 건지 아닌지 모른다.** 모르면 안 된 것으로 친다
      debugPrint('Live Activity $method 가 제때 답하지 않았다');
      return false;
    }
  }
}
