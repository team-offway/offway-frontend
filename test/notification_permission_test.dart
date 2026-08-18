import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/notification/application/notification_provider.dart';
import 'package:offway/features/notification/domain/app_notification.dart';
import 'package:offway/features/notification/presentation/notification_screen.dart';

/// 알림 권한이 꺼져 있으면 목록 대신 켜기 안내를 보여준다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool? enabled,
    int notificationCount = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // null이면 '아직 못 읽음' — 프로바이더를 끝나지 않는 Future로 둔다
          if (enabled != null)
            notificationEnabledProvider.overrideWith((ref) async => enabled)
          else
            notificationEnabledProvider.overrideWith(
              (ref) => Completer<bool>().future,
            ),
          notificationFeedProvider.overrideWith(
            (ref) async =>
                (notifications: const <AppNotification>[], unreadCount: 0),
          ),
          // 배지가 스스로 서버를 부른다 — 안 덮으면 그 요청 타이머가 남는다
          hasUnreadNotificationsProvider.overrideWith(_StubBadge.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('권한이 꺼져 있으면 켜기 안내를 보여준다', (tester) async {
    await pump(tester, enabled: false);
    await tester.pumpAndSettle();

    expect(find.text('알림이 꺼져있어요'), findsOneWidget);
    expect(find.text('알림 켜기'), findsOneWidget);
    // 권한이 없으면 목록은 그리지 않는다
    expect(find.text('오래된 알림은 30일 후 자동 삭제돼요'), findsNothing);
  });

  testWidgets('권한이 켜져 있으면 목록을 그린다', (tester) async {
    await pump(tester, enabled: true);
    await tester.pumpAndSettle();

    expect(find.text('알림이 꺼져있어요'), findsNothing);
    expect(find.text('알림이 없어요'), findsOneWidget);
  });

  testWidgets('아직 못 읽었으면 안내를 띄우지 않는다', (tester) async {
    // 권한이 있는데 안내가 깜빡이면 사용자를 설정으로 헛걸음시킨다
    await pump(tester, enabled: null);

    expect(find.text('알림이 꺼져있어요'), findsNothing);
  });
}

/// 서버를 부르지 않는 배지
class _StubBadge extends UnreadNotificationsBadge {
  @override
  bool build() => false;
}
