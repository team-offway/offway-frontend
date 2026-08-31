import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'notification_provider.dart';

final pushPresenterProvider = Provider<PushPresenter>((ref) {
  final presenter = PushPresenter();
  // 배너를 누르면 알림 목록에서 누른 것과 같은 곳으로 보낸다.
  // 라우터를 직접 잡는다 — 여기는 위젯 트리 바깥이라 context가 없다
  presenter.onOpenRoute = (route) => ref.read(appRouterProvider).push(route);
  presenter.onArrived = () {
    // 방금 온 알림은 안 읽음이 확실하다 — 서버에 묻지 않고 켠다
    ref.read(hasUnreadNotificationsProvider.notifier).markArrived();
    // 알림 화면이 열려 있으면 새 알림이 바로 목록에 붙는다.
    // autoDispose라 닫혀 있으면 이 호출은 아무 일도 하지 않는다
    ref.invalidate(notificationFeedProvider);
  };
  presenter.onRead = (notificationId) async {
    try {
      final unread = await ref
          .read(notificationRepositoryProvider)
          .markRead(notificationId);
      // 서버가 센 값으로 맞춘다 — 배너로 들어온 그 알림만 읽은 것이라
      // 다른 안 읽은 알림이 남아 있으면 종에 점이 그대로 있어야 한다
      ref.read(hasUnreadNotificationsProvider.notifier).setUnreadCount(unread);
    } on Object {
      // 읽음 표시가 안 남는 것뿐이다 — 알림함에서 다시 누를 수 있다.
      // 그래도 새 알림이 온 것은 사실이라 목록은 다시 읽는다
      ref.read(hasUnreadNotificationsProvider.notifier).markArrived();
    }
    ref.invalidate(notificationFeedProvider);
  };
  return presenter;
});

/// 푸시가 도착했을 때의 뒤처리 — 배지·목록 갱신과 배너 탭 이동.
///
/// **배너는 서버가 실은 문구로 시스템이 그린다**(core #358). 앱이 켜져 있을
/// 때도 `setForegroundNotificationPresentationOptions(alert: true)` 덕에
/// 시스템이 띄우므로, 여기서 또 그리면 **같은 알림이 두 번 뜬다.**
///
/// 다만 `notification` 없이 오는 메시지도 있을 수 있어(옛 서버·다른 발송
/// 경로) 그때는 앱이 대신 그린다 — [_needsLocalBanner]. 그 문구는 목록 셀과
/// 같은 [notificationBody]를 쓴다.
class PushPresenter {
  PushPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// 배너를 누른 사람을 보낼 곳 — 앱이 라우터를 들고 있는 쪽에서 채운다.
  ///
  /// 알림 목록에서 누를 때와 같은 규칙([notificationDestination])을 쓴다.
  void Function(String route)? onOpenRoute;

  /// 배너로 들어온 그 알림을 읽음으로 넘긴다 (core #367).
  ///
  /// 배너를 눌러 내용을 확인했는데 종에 점이 남으면, 알림함에서 한 번 더
  /// 눌러야 읽음이 된다 — 확인한 사람에게 "안 읽은 알림이 있다"고 계속
  /// 말하는 셈이다.
  void Function(int notificationId)? onRead;

  /// 푸시가 막 도착했다 — 홈 종 배지를 켜고 알림 목록을 다시 읽게 한다.
  ///
  /// 배너만 띄우고 끝내면 **배너는 떴는데 앱에 돌아오면 티가 안 난다.**
  /// 종에 점이 없고, 알림 화면이 열려 있었다면 새 알림이 안 보인다.
  void Function()? onArrived;

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
      // 앱을 띄운 알림으로 한 번만 이동한다. 아래 두 길이 같은 알림을
      // 가리킬 수 있어, 먼저 잡히는 쪽만 쓴다
      await _openFromLaunch();
    } on Object catch (e) {
      // 푸시는 덤이다 — 초기화가 실패해도 앱은 그대로 간다
      debugPrint('푸시 표시 준비 실패: $e');
    }
  }

  /// 앱을 보고 있는 동안 온 푸시 하나를 처리한다.
  Future<void> show(RemoteMessage message) async {
    // 배너가 뜨든 안 뜨든 **알림이 도착한 것은 사실이다.** 배지와 목록을
    // 먼저 알린다 — 그러지 않으면 앱 안에 흔적이 없어 온 줄도 모른다
    onArrived?.call();

    // 서버가 문구를 실어 보냈으면 시스템이 이미 배너를 그렸다(core #358).
    // 여기서 또 그리면 같은 알림이 두 번 뜬다
    if (!needsLocalBanner(message)) return;

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

  /// 앱이 배너를 대신 그려야 하는가.
  ///
  /// 서버는 `notification`을 실어 보내고(core #358), 그러면 앱이 켜져 있어도
  /// 시스템이 배너를 띄운다 — `setForegroundNotificationPresentationOptions`
  /// 로 켜 뒀기 때문이다. 그때 앱이 또 그리면 **같은 알림이 두 번 뜬다.**
  ///
  /// 문구 없이 오는 메시지에만 우리가 나선다. 옛 서버나 다른 발송 경로가
  /// 그럴 수 있고, 그때까지 배너를 잃지 않는다.
  @visibleForTesting
  static bool needsLocalBanner(RemoteMessage message) =>
      message.notification == null;

  /// 앱이 꺼져 있다가 **배너로 열린** 경우의 이동.
  ///
  /// 길이 둘이다. FCM이 직접 띄운 배너는 [FirebaseMessaging.getInitialMessage]
  /// 로 오고, **우리가 띄운 배너**는 [getNotificationAppLaunchDetails]로 온다 —
  /// `onDidReceiveNotificationResponse`는 앱이 살아 있을 때의 탭만 받기 때문이다.
  ///
  /// 앱을 보는 중에 배너가 떴는데 누르지 않고 앱을 닫으면 그 배너는 알림센터에
  /// 남는다. 나중에 그것을 눌러 앱이 뜨면 두 번째 길로 오므로, 이게 없으면
  /// 알림센터에서 연 사람만 조용히 홈에 떨어진다.
  ///
  /// **한 번만 이동한다.** 둘 다 값이 있으면 같은 알림으로 화면을 두 번 밀어
  /// 올려 뒤로가기가 어색해진다.
  Future<void> _openFromLaunch() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _openFrom(initial);
      return;
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch!.notificationResponse;
      if (response != null) _onTapBanner(response);
    }
  }

  /// 로컬 알림 배너를 눌렀을 때
  void _onTapBanner(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      openFromPayload(data);
    } on Object catch (e) {
      debugPrint('푸시 payload를 읽지 못했다: $e');
    }
  }

  /// FCM이 직접 전한 메시지로 앱이 열렸을 때
  void _openFrom(RemoteMessage message) => openFromPayload(message.data);

  /// 배너로 앱에 들어왔다 — 갈 곳으로 보내고, 그 알림을 읽음으로 넘긴다.
  @visibleForTesting
  void openFromPayload(Map<String, dynamic> data) {
    final type = NotificationType.parse(data['type'] as String?);
    // 서버는 data 값을 전부 String으로 싣는다
    final courseId = int.tryParse(data['courseId']?.toString() ?? '');
    final route = notificationDestination(type, courseId);
    if (route != null) onOpenRoute?.call(route);

    // 배너를 눌러 확인했으니 읽은 것이다 (core #367이 id를 실어 준다).
    // 옛 서버는 이 키가 없다 — 그때는 도착만 알려 목록에서 눌러 읽게 둔다
    final notificationId = int.tryParse(
      data['notificationId']?.toString() ?? '',
    );
    if (notificationId != null) {
      onRead?.call(notificationId);
    } else {
      onArrived?.call();
    }
  }
}
