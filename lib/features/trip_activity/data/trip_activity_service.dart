import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/trip_countdown.dart';

/// 잠금화면·다이나믹 아일랜드(Live Activity)를 여닫는 다리.
///
/// **UI는 Swift가 그린다.** Flutter 위젯으로는 잠금화면을 그릴 수 없어,
/// 값만 네이티브로 넘기고 화면은 Widget Extension(SwiftUI)이 맡는다.
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
  /// 하루에 한 번꼴로 바뀌는 값이라(D-3 → D-2) 자주 부를 이유가 없다 —
  /// 앱이 앞으로 나올 때 한 번이면 충분하다
  Future<void> start(TripCountdown trip, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _invoke('start', {
      'courseId': trip.courseId,
      'regionName': trip.regionName,
      'headline': trip.headline(at),
      'rangeLabel': trip.rangeLabel,
      'durationLabel': trip.durationLabel,
      'compactLabel': trip.compactLabel(at),
    });
  }

  /// 떠 있는 잠금화면을 내린다 — 여행이 끝났거나 코스를 지웠을 때
  Future<void> end() => _invoke('end', const {});

  /// 네이티브가 답하지 않을 때 기다리는 한도.
  ///
  /// ActivityKit 이 매달리면 `invokeMethod` 의 Future 가 영영 완결되지
  /// 않는다 — 앱 재개마다 부르는 자리라 그대로 쌓인다
  static const _timeout = Duration(seconds: 5);

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>(method, args).timeout(_timeout);
    } on PlatformException catch (e) {
      // 잠금화면이 안 뜨는 것뿐이다 — 앱이 하던 일을 막지 않는다
      debugPrint('Live Activity $method 실패: ${e.message}');
    } on MissingPluginException {
      debugPrint('Live Activity 네이티브가 없는 빌드다 ($method)');
    } on TimeoutException {
      debugPrint('Live Activity $method 가 제때 답하지 않았다');
    }
  }
}
