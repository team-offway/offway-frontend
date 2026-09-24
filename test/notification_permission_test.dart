import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/notification/application/notification_provider.dart';
import 'package:offway/features/notification/domain/app_notification.dart';
import 'package:offway/features/notification/presentation/notification_screen.dart';
import 'package:offway/features/notification/application/notification_permission_provider.dart';

/// 알림 권한이 꺼져 있으면 목록 대신 켜기 안내를 보여준다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool? enabled,
    int notificationCount = 0,
    double statusBar = 0,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: EdgeInsets.only(top: statusBar)),
            child: child!,
          ),
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

  // 시안(402×874, 상단바 98 = 상태바 54 + 44)의 제목 위치 — 가운데 정렬이면
  // 130px 가까이 내려앉는다
  for (final (enabled, title, figmaTop) in [
    (true, '알림이 없어요', 288.0 + 91),
    (false, '알림이 꺼져있어요', 264.5 + 62),
  ]) {
    testWidgets('$title 는 시안 높이에 놓인다', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, enabled: enabled, statusBar: 54);
      await tester.pumpAndSettle();

      final top = tester.getTopLeft(find.text(title)).dy;
      expect(top, closeTo(figmaTop, 4));
    });
  }

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
