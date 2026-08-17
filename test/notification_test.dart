import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/notification/application/notification_provider.dart';
import 'package:offway/features/notification/domain/app_notification.dart';
import 'package:offway/features/notification/presentation/notification_screen.dart';

void main() {
  AppNotification notification({
    int id = 1,
    NotificationType type = NotificationType.tripTomorrow,
    bool read = false,
    int? courseId = 7,
  }) => AppNotification(
    id: id,
    type: type,
    read: read,
    courseId: courseId,
    createdAt: DateTime.now(),
  );

  /// 알림 화면만 띄운다
  Future<void> pump(
    WidgetTester tester, {
    List<AppNotification> items = const [],
    int unreadCount = 0,
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationFeedProvider.overrideWith(
            (ref) async => (notifications: items, unreadCount: unreadCount),
          ),
          notificationEnabledProvider.overrideWith((ref) => enabled),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('목록', () {
    testWidgets('안 읽은 건이 하늘색으로 구분된다', (tester) async {
      await pump(
        tester,
        items: [notification(), notification(id: 2, read: true)],
        unreadCount: 1,
      );

      final tiles = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(NotificationScreen),
          matching: find.byType(Container),
        ),
      );
      final colors = tiles.map((t) => t.color).nonNulls.toSet();
      // 읽음·안읽음 배경이 서로 달라야 구분이 된다
      expect(colors.length, 2);
    });

    testWidgets('보관 기간을 안내한다', (tester) async {
      await pump(tester, items: [notification()]);
      expect(find.text('오래된 알림은 30일 후 자동 삭제돼요'), findsOneWidget);
    });

    testWidgets('알림이 없으면 빈 상태를 보여준다', (tester) async {
      await pump(tester);

      expect(find.text('알림이 없어요'), findsOneWidget);
      expect(find.text('새로운 소식이 오면 알려드릴게요'), findsOneWidget);
    });

    testWidgets('권한이 꺼져 있으면 켜기 안내를 보여준다', (tester) async {
      await pump(tester, items: [notification()], enabled: false);

      expect(find.text('알림이 꺼져있어요'), findsOneWidget);
      expect(find.text('알림 켜기'), findsOneWidget);
      // 권한이 없으면 목록은 그리지 않는다
      expect(find.text('오래된 알림은 30일 후 자동 삭제돼요'), findsNothing);
    });
  });

  group('문구는 앱이 고른다', () {
    // 서버는 type만 준다 — 문구를 서버에 굳히면 쌓인 알림이 옛 문구로 남는다
    testWidgets('여행 이후 알림은 연차 기록을 청한다', (tester) async {
      await pump(
        tester,
        items: [notification(type: NotificationType.tripAfter)],
      );

      expect(find.textContaining('다녀오셨나요?'), findsOneWidget);
      expect(find.textContaining('연차를 사용했다면 기록해 주세요.'), findsOneWidget);
    });

    testWidgets('내일 여행 알림은 짐을 챙기라고 한다', (tester) async {
      await pump(tester, items: [notification()]);
      expect(find.textContaining('내일은 여행을 떠나는 날이에요.'), findsOneWidget);
    });

    testWidgets('모르는 종류도 목록에서 사라지지 않는다', (tester) async {
      // 서버가 값을 늘려도 앱을 업데이트하지 않은 사용자에게 알림이 간다.
      // 파싱에서 터지면 새 알림 하나 때문에 목록 전체가 안 보인다
      final unknown = AppNotification.fromJson(const {
        'id': 9,
        'type': 'SOMETHING_NEW',
        'read': false,
      });
      expect(unknown.type, NotificationType.unknown);

      await pump(tester, items: [unknown]);
      expect(find.text('새로운 소식이 도착했어요.'), findsOneWidget);
    });
  });

  group('상대 시각', () {
    final now = DateTime(2026, 8, 18, 12);

    test('1분 안이면 방금전', () {
      final item = notification();
      expect(
        AppNotification(
          id: item.id,
          type: item.type,
          read: item.read,
          createdAt: now.subtract(const Duration(seconds: 30)),
        ).timeLabel(now),
        '방금전',
      );
    });

    test('분·시간·일 단위로 올라간다', () {
      AppNotification at(Duration ago) => AppNotification(
        id: 1,
        type: NotificationType.tripTomorrow,
        read: false,
        createdAt: now.subtract(ago),
      );

      expect(at(const Duration(minutes: 3)).timeLabel(now), '3분 전');
      expect(at(const Duration(hours: 5)).timeLabel(now), '5시간 전');
      expect(at(const Duration(days: 2)).timeLabel(now), '2일 전');
    });

    test('기기 시계가 느려 미래로 보여도 방금전이다', () {
      final future = AppNotification(
        id: 1,
        type: NotificationType.tripTomorrow,
        read: false,
        createdAt: now.add(const Duration(minutes: 5)),
      );
      expect(future.timeLabel(now), '방금전');
    });

    test('만든 시각이 없으면 비운다', () {
      expect(
        const AppNotification(
          id: 1,
          type: NotificationType.tripTomorrow,
          read: false,
        ).timeLabel(now),
        '',
      );
    });
  });

  group('탭하면 이동한다', () {
    /// 이동 경로를 잡아 두는 라우터로 감싼다
    Future<List<String>> pumpWithRouter(
      WidgetTester tester,
      AppNotification item,
    ) async {
      final visited = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const NotificationScreen(),
            routes: [
              GoRoute(
                path: 'leave',
                builder: (_, _) {
                  visited.add('/leave');
                  return const SizedBox.shrink();
                },
              ),
              GoRoute(
                path: 'my-courses/:savedId',
                builder: (_, state) {
                  visited.add('/my-courses/${state.pathParameters['savedId']}');
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationFeedProvider.overrideWith(
              (ref) async => (notifications: [item], unreadCount: 1),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return visited;
    }

    testWidgets('여행 이후 알림은 내 연차로 간다', (tester) async {
      // 시안 흐름: 알림 → 내 연차 → "다녀오셨나요?" 모달
      final visited = await pumpWithRouter(
        tester,
        notification(type: NotificationType.tripAfter),
      );

      await tester.tap(find.textContaining('다녀오셨나요?'));
      await tester.pumpAndSettle();

      expect(visited, ['/leave']);
    });

    testWidgets('내일 여행 알림은 그 코스로 간다', (tester) async {
      final visited = await pumpWithRouter(tester, notification(courseId: 7));

      await tester.tap(find.textContaining('내일은 여행을'));
      await tester.pumpAndSettle();

      expect(visited, ['/my-courses/7']);
    });

    testWidgets('코스가 없는 알림은 눌러도 이동하지 않는다', (tester) async {
      // 알림은 코스가 지워져도 남는다 — 갈 곳 없는 이동은 하지 않는다
      final visited = await pumpWithRouter(
        tester,
        notification(courseId: null),
      );

      await tester.tap(find.textContaining('내일은 여행을'));
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
    });
  });
}
