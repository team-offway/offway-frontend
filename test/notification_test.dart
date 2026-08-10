import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/features/notification/presentation/notification_screen.dart';

void main() {
  testWidgets('알림 목록: 안 읽은 건이 하늘색으로 구분된다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NotificationScreen())),
    );
    await tester.pump();

    expect(find.text('알림'), findsNWidgets(4)); // 상단바 + 카드 3개 라벨
    expect(find.text("오늘은 '정선 여행'을 떠나는 날이에요."), findsOneWidget);
    expect(find.text('오래된 알림은 30일 후 자동 삭제돼요'), findsOneWidget);
  });

  testWidgets('알림이 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => const <AppNotification>[],
          ),
        ],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('알림이 없어요'), findsOneWidget);
    expect(find.text('새로운 소식이 오면 알려드릴게요'), findsOneWidget);
  });

  testWidgets('권한이 꺼져 있으면 켜기 안내를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationEnabledProvider.overrideWith((ref) => false)],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('알림이 꺼져있어요'), findsOneWidget);
    expect(find.text('알림 켜기'), findsOneWidget);
    // 권한이 없으면 목록은 그리지 않는다
    expect(find.text('오래된 알림은 30일 후 자동 삭제돼요'), findsNothing);
  });
}
