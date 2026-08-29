import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../domain/app_notification.dart';

final pushPresenterProvider = Provider<PushPresenter>((ref) {
  final presenter = PushPresenter();
  // 배너를 누르면 알림 목록에서 누른 것과 같은 곳으로 보낸다.
  // 라우터를 직접 잡는다 — 여기는 위젯 트리 바깥이라 context가 없다
  presenter.onOpenRoute = (route) => ref.read(appRouterProvider).push(route);
  return presenter;
});

/// 서버가 보낸 푸시를 **앱이 직접 배너로 그린다** (core #270).
///
/// 서버는 `notification` 필드 없이 `data`만 싣는다 — 문구를 서버에 굳히지
/// 않으려는 것이다. 그 대가로 시스템이 배너를 대신 그려주지 않으므로, 앱이
/// `data.type`을 읽어 문구를 만들고 로컬 알림으로 띄운다. 이 코드가 없으면
/// **알림 목록에는 쌓이는데 배너가 안 뜬다.**
///
/// 문구는 목록 셀과 같은 [notificationBody]를 쓴다 — 두 곳에 따로 적으면
/// 한쪽만 고쳐져 배너와 목록이 다른 말을 한다.
///
/// **앱이 화면에 떠 있을 때만 우리가 그린다.** 백그라운드·종료 상태의
/// data-only 메시지는 iOS가 앱을 깨워주지 않으면 도착조차 하지 않는다.
/// 그 경우까지 배너를 띄우려면 서버가 `notification` 필드를 함께 실어야 한다
/// (아래 [kBackgroundPushNeedsServerNotification] 참고).
class PushPresenter {
  PushPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// 배너를 누른 사람을 보낼 곳 — 앱이 라우터를 들고 있는 쪽에서 채운다.
  ///
  /// 알림 목록에서 누를 때와 같은 규칙([notificationDestination])을 쓴다.
  void Function(String route)? onOpenRoute;

  bool _ready = false;

  /// 앱 시작 때 한 번 부른다.
  ///
  /// 권한은 [PushRegistration]이 이미 묻는다 — 여기서 또 물으면 팝업이 두 번
  /// 뜨는 것처럼 보이므로 요청하지 않는다.
  Future<void> start() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            // 권한은 PushRegistration이 맡는다
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTapBanner,
      );
      _ready = true;

      // 앱을 보고 있는 동안 온 푸시
      FirebaseMessaging.onMessage.listen(show);
      // 배너를 눌러 앱이 열린 경우 (백그라운드에 있던 앱)
      FirebaseMessaging.onMessageOpenedApp.listen(_openFrom);
      // 앱이 꺼져 있다가 배너로 열린 경우 — 첫 프레임 전에 온 것을 받는다
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openFrom(initial);
    } on Object catch (e) {
      // 푸시는 덤이다 — 초기화가 실패해도 앱은 그대로 간다
      debugPrint('푸시 표시 준비 실패: $e');
    }
  }

  /// data 메시지 하나를 배너로 띄운다.
  Future<void> show(RemoteMessage message) async {
    if (!_ready) return;
    final type = NotificationType.parse(message.data['type'] as String?);
    try {
      await _plugin.show(
        // 같은 종류가 잇따라 오면 앞의 것을 덮어쓴다 — 같은 말이 여러 줄
        // 쌓이면 알림 센터만 지저분해진다
        id: type.index,
        title: '알림',
        body: notificationBody(type),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
        ),
        // 눌렀을 때 어디로 갈지는 그 시점에 푼다 — 여기서 라우트를 미리
        // 만들면 코스가 지워진 경우를 다시 판정할 수 없다
        payload: jsonEncode(message.data),
      );
    } on Object catch (e) {
      debugPrint('푸시 배너 표시 실패: $e');
    }
  }

  /// 로컬 알림 배너를 눌렀을 때
  void _onTapBanner(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _open(data);
    } on Object catch (e) {
      debugPrint('푸시 payload를 읽지 못했다: $e');
    }
  }

  /// FCM이 직접 전한 메시지로 앱이 열렸을 때
  void _openFrom(RemoteMessage message) => _open(message.data);

  void _open(Map<String, dynamic> data) {
    final type = NotificationType.parse(data['type'] as String?);
    // courseId는 문자열로 온다 — 서버가 data 값을 전부 String으로 싣는다
    final courseId = int.tryParse(data['courseId']?.toString() ?? '');
    final route = notificationDestination(type, courseId);
    if (route != null) onOpenRoute?.call(route);
  }
}

/// 백그라운드·종료 상태에서 배너가 뜨려면 **서버가 `notification` 필드를
/// 함께 실어야 한다.**
///
/// iOS는 `notification` 없는 data-only 메시지를 배너로 그리지 않고,
/// `content-available`만으로는 앱을 깨울지도 시스템이 정한다. 지금 서버는
/// data만 보내므로(core #270 `FcmPushSender`) **앱이 화면에 떠 있을 때만**
/// 배너가 뜬다.
///
/// 서버가 `notification`을 실어도 문구가 서버에 굳지는 않는다 — 앱이 켜져
/// 있을 때는 여전히 이 클래스가 그리고, 꺼져 있을 때만 시스템이 서버 문구를
/// 쓴다. 백엔드와 정할 문제라 여기 남긴다.
const kBackgroundPushNeedsServerNotification = true;
