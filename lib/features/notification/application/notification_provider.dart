import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

/// 알림 목록 한 페이지와 안읽음 전체 수.
///
/// [unreadCount]는 이 페이지가 아니라 **전체** 안읽음 수다 — 홈 배지가 쓴다.
typedef NotificationFeed = ({
  List<AppNotification> notifications,
  int unreadCount,
});

/// 알림 목록 (`GET /notifications`).
///
/// 화면을 나갔다 오면 다시 읽는다 — 읽음 처리와 새 알림이 서버에서 온다.
final notificationFeedProvider = FutureProvider.autoDispose<NotificationFeed>(
  (ref) => ref.watch(notificationRepositoryProvider).fetch(),
);

/// 홈 종 아이콘의 배지 — 안 읽은 알림이 하나라도 있는지.
///
/// **목록과 따로 둔다.** 목록은 autoDispose라 알림 화면을 나가면 버려지는데,
/// 배지는 홈에 머무는 내내 떠 있어야 한다.
///
/// 처음 켜질 때 스스로 한 번 조회한다 — 홈이 알림 화면을 거치지 않고도
/// 배지를 그릴 수 있어야 한다. 그 뒤로는 목록 조회·읽음 처리가 돌려주는
/// 수로 갱신한다([setUnreadCount]) — 배지를 고치려고 목록을 다시 부르지
/// 않는다.
///
/// 읽지 못했으면 켜지 않는다 — 잘못 켠 배지는 눌러도 빈 목록이라
/// 사용자를 두 번 속인다.
final hasUnreadNotificationsProvider =
    NotifierProvider<UnreadNotificationsBadge, bool>(
      UnreadNotificationsBadge.new,
    );

class UnreadNotificationsBadge extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final feed = await ref.read(notificationRepositoryProvider).fetch();
      state = feed.unreadCount > 0;
    } on ApiException {
      // 배지는 덤이다 — 못 읽었으면 끈 채로 둔다
    }
  }

  /// 서버가 준 안읽음 수로 배지를 맞춘다
  void setUnreadCount(int count) => state = count > 0;
}
