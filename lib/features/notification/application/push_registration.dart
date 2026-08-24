import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/device_repository.dart';

final pushRegistrationProvider = Provider<PushRegistration>(
  (ref) => PushRegistration(ref),
);

/// 푸시를 받을 준비 — 권한을 묻고 FCM 토큰을 서버에 등록한다.
///
/// **실패해도 앱은 그대로 간다.** 푸시는 덤이라 권한 거부·APNs 미설정·서버
/// 오류 어느 쪽이든 조용히 넘어간다. 여기서 던지면 알림 하나 때문에 앱이
/// 안 뜬다.
class PushRegistration {
  PushRegistration(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshSubscription;

  /// 해제된 뒤에는 등록하지 않는다.
  ///
  /// [start]는 권한 팝업·토큰 조회로 몇 초가 걸린다. 그 사이 로그아웃하면
  /// DELETE가 먼저 나가고 뒤늦은 POST가 기기를 되살려, 로그아웃했는데
  /// 푸시가 계속 온다.
  bool _stopped = false;

  /// 기기 알림 권한이 켜져 있는지 — 알림 화면이 안내를 띄울지 정한다.
  ///
  /// **묻지 않고 지금 상태만 본다.** 권한 팝업은 [start]가 앱 시작 때 한 번
  /// 띄우고, iOS는 거부한 사람에게 두 번 묻지 않는다 — 여기서 다시 부르면
  /// 아무 일도 없이 거부 상태만 돌아온다.
  ///
  /// 읽지 못하면 켜진 것으로 본다. 실제로는 켜져 있는데 안내를 띄우면
  /// 사용자를 설정으로 헛걸음시킨다.
  Future<bool> isAuthorized() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus != AuthorizationStatus.denied;
    } on Object catch (e) {
      debugPrint('알림 권한을 읽지 못했다: $e');
      return true;
    }
  }

  /// 앱이 뜬 뒤와 로그인 직후에 부른다.
  ///
  /// 권한을 묻고, 받은 토큰을 등록하고, 갱신을 구독한다. 토큰은 서버가
  /// 몇 번을 받아도 한 행만 두므로 매번 보내도 된다.
  ///
  /// 등록 자체는 로그인이 있어야 한다(`/devices`는 Bearer 전용, core #320).
  /// 앱 시작이 로그인 화면이었다면 여기서는 권한·구독만 잡히고 등록은
  /// 건너뛴다 — 로그인이 끝나면 [LoginScreen]이 다시 부른다.
  Future<void> start() async {
    _stopped = false;
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS는 권한을 받아야 APNs 토큰이 나온다. 거부해도 앱은 그대로 간다
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('푸시 권한 거부 — 기기를 등록하지 않는다');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        // APNs 설정이 덜 됐거나 시뮬레이터다 — 둘 다 실기기에서만 풀린다
        debugPrint('FCM 토큰을 받지 못했다 (APNs 미설정이거나 시뮬레이터)');
        return;
      }
      await _register(token);

      // 토큰은 재설치·복원·주기적 갱신으로 바뀐다. 놓치면 그때부터
      // 푸시가 조용히 끊긴다
      _refreshSubscription ??= messaging.onTokenRefresh.listen(_register);
    } on Object catch (e) {
      // PlatformException까지 포함해 전부 삼킨다 — 푸시 하나가 앱을
      // 막아서는 안 된다
      debugPrint('푸시 등록 실패: $e');
    }
  }

  Future<void> _register(String token) async {
    if (_stopped) return;
    try {
      // 로그인 전에는 부르지 않는다 — JWT 없이 가면 403만 남고, 서버는
      // 기기를 누구 것으로 둘지 알 수 없다. 토큰 갱신 이벤트가 로그아웃
      // 상태에서 와도 같다
      if (await _ref.read(secureStorageProvider).accessToken == null) {
        debugPrint('로그인 전이라 기기를 등록하지 않는다');
        return;
      }
      await _ref.read(deviceRepositoryProvider).register(token);
    } on Object catch (e) {
      debugPrint('기기 등록 실패: $e');
    }
  }

  /// 로그아웃·탈퇴에서 부른다 — 이 기기로 알림이 가지 않게 한다.
  Future<void> stop() async {
    // 먼저 세운다 — 뒤늦게 돌아온 start()의 등록을 막는다
    _stopped = true;
    try {
      await _refreshSubscription?.cancel();
    } on Object catch (e) {
      // 구독 취소가 실패해도 해제는 해야 한다
      debugPrint('토큰 갱신 구독 취소 실패: $e');
    } finally {
      _refreshSubscription = null;
    }
    try {
      await _ref.read(deviceRepositoryProvider).unregister();
    } on Object catch (e) {
      debugPrint('기기 해제 실패: $e');
    }
  }
}
