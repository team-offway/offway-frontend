import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/notification/application/notification_provider.dart';
import 'package:offway/features/notification/data/notification_repository.dart';
import 'package:offway/features/notification/domain/app_notification.dart';
import 'package:offway/features/notification/presentation/notification_screen.dart';
import 'package:offway/features/notification/application/notification_permission_provider.dart';

/// 알림 화면 오른쪽 위 '모두 읽음' — 안 읽은 알림을 한 번에 읽음으로 바꾼다.
class _FakeRepository extends NotificationRepository {
  _FakeRepository({required this.unread, this.fail = false}) : super(Dio());

  int unread;
  final bool fail;
  int markAllCalls = 0;

  @override
  Future<({List<AppNotification> notifications, int unreadCount})> fetch({
    int page = 0,
    int size = 20,
  }) async => (
    notifications: [
      for (var i = 1; i <= 2; i++)
        AppNotification(
          id: i,
          type: NotificationType.tripTomorrow,
          read: i > unread,
          courseId: 7,
          createdAt: DateTime.now(),
        ),
    ],
    unreadCount: unread,
  );

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    if (fail) {
      throw const ApiException(status: 500, code: 'X', detail: '서버 오류');
    }
    unread = 0;
    return 0;
  }
}

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _FakeRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        notificationEnabledProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('누르면 전부 읽음으로 바꾸고 알린다', (tester) async {
    final repo = _FakeRepository(unread: 2);
    final container = await pump(tester, repo);

    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(repo.markAllCalls, 1);
    expect(find.text('모든 알림을 읽음 처리했어요.'), findsOneWidget);
    // 홈 종 아이콘의 점도 꺼진다
    expect(container.read(hasUnreadNotificationsProvider), isFalse);
  });

  testWidgets('안 읽은 알림이 없으면 눌러도 요청하지 않는다', (tester) async {
    final repo = _FakeRepository(unread: 0);
    await pump(tester, repo);

    expect(find.text('모두 읽음'), findsOneWidget);
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(repo.markAllCalls, 0);
  });

  testWidgets('실패하면 다시 시도하라고 알린다', (tester) async {
    final repo = _FakeRepository(unread: 2, fail: true);
    await pump(tester, repo);

    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(find.text('읽음 처리하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
  });
}
