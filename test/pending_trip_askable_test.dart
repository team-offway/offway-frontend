import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/course/domain/pending_trip.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

/// "다녀오셨나요?" 모달을 **언제** 띄우는지 고정한다.
///
/// 서버 알림은 여행 다음 날 20시(KST)에 오는데 `pending-trips`는 자정에
/// 넘어온다. 앱이 그대로 띄우면 아침에 홈에서 먼저 묻고 저녁에 알림이 또
/// 온다 — 알림과 같은 시각까지 미룬다.
void main() {
  PendingTrip endedOn(DateTime end) => PendingTrip(
    courseId: 1,
    regionName: '정선군',
    startDate: end.subtract(const Duration(days: 2)),
    endDate: end,
    consumedLeaveDays: 3,
  );

  group('물어봐도 되는 시각', () {
    // 7/22에 끝난 여행 — 알림은 7/23 20:00 KST(= 11:00 UTC)에 온다
    final trip = endedOn(DateTime(2026, 7, 22));

    test('여행 다음 날 20시(KST)부터다', () {
      expect(trip.askableFrom, DateTime.utc(2026, 7, 23, 11));
    });

    test('다음 날 자정을 넘겨도 아직은 아니다', () {
      expect(trip.isAskableAt(DateTime.utc(2026, 7, 22, 15, 30)), isFalse);
    });

    test('19:59는 아직이고 20:00은 된다', () {
      expect(trip.isAskableAt(DateTime.utc(2026, 7, 23, 10, 59)), isFalse);
      expect(trip.isAskableAt(DateTime.utc(2026, 7, 23, 11)), isTrue);
    });

    test('그 뒤로는 몇 날이 지나도 된다', () {
      expect(trip.isAskableAt(DateTime.utc(2026, 8, 1, 3)), isTrue);
    });

    test('기기 시간대가 달라도 같은 순간을 본다', () {
      // 한국 20:00 = 파리 13:00 — 현지 시각이 아니라 그 순간으로 잰다
      final parisNoon = DateTime.utc(2026, 7, 23, 10);
      expect(trip.isAskableAt(parisNoon.toLocal()), isFalse);
      expect(
        trip.isAskableAt(parisNoon.add(const Duration(hours: 1)).toLocal()),
        isTrue,
      );
    });
  });

  group('화면', () {
    // 오늘 끝난 여행은 내일 20시까지 물을 수 없다 — 지금이 몇 시든 같다
    final endedToday = endedOn(DateUtils.dateOnly(DateTime.now()));
    // 열흘 전에 끝난 여행은 언제든 물어도 된다
    final endedLongAgo = endedOn(
      DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 10)),
    );

    Future<void> pumpHome(WidgetTester tester, PendingTrip trip) async {
      // 연차가 없으면 홈이 온보딩으로 보내 버린다 — 있는 사람으로 둔다
      const user = <String, dynamic>{
        'nickname': '영찬',
        'remainingLeaveDays': 12.0,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) async => user),
            homeSnapshotProvider.overrideWith(
              (ref) async => HomeSnapshot(user: user, regions: const []),
            ),
            pendingTripProvider.overrideWith((ref) async => trip),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpLeaveFromNotification(
      WidgetTester tester,
      PendingTrip trip, {
      required int? notificationCourseId,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingTripProvider.overrideWith((ref) async => trip),
            myLeaveProvider.overrideWith(
              (ref) async => const MyLeave(
                totalDays: 30,
                usedDays: 7,
                remainingDays: 23,
                usages: [],
              ),
            ),
            leaveUsagesProvider.overrideWith(
              (ref) async => const <LeaveUsage>[],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MyLeaveScreen(
              fromNotification: true,
              notificationCourseId: notificationCourseId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('홈 — 알림 시각 전에는 묻지 않는다', (tester) async {
      await pumpHome(tester, endedToday);
      expect(find.textContaining('다녀오셨나요?'), findsNothing);
    });

    testWidgets('홈 — 알림 시각이 지난 여행은 묻는다', (tester) async {
      await pumpHome(tester, endedLongAgo);
      expect(find.textContaining('다녀오셨나요?'), findsOneWidget);
    });

    testWidgets('그 여행의 알림을 눌러 들어오면 시각을 따지지 않는다', (tester) async {
      // 알림이 왔다는 것이 곧 물어볼 때라는 뜻이다 — 기기 시계가 느려도 뜬다
      await pumpLeaveFromNotification(
        tester,
        endedToday,
        notificationCourseId: endedToday.courseId,
      );
      expect(find.textContaining('다녀오셨나요?'), findsOneWidget);
    });

    testWidgets('다른 여행의 알림으로 들어왔으면 시각을 따진다', (tester) async {
      // 옛 알림을 아침에 눌렀는데 어제 끝난 다른 여행이 걸렸다 — 그 여행은
      // 아직 물을 때가 아니다
      await pumpLeaveFromNotification(
        tester,
        endedToday,
        notificationCourseId: endedToday.courseId + 1,
      );
      expect(find.textContaining('다녀오셨나요?'), findsNothing);
    });

    testWidgets('코스를 모르는 알림으로 들어와도 시각은 따진다', (tester) async {
      await pumpLeaveFromNotification(
        tester,
        endedToday,
        notificationCourseId: null,
      );
      expect(find.textContaining('다녀오셨나요?'), findsNothing);
    });
  });
}
