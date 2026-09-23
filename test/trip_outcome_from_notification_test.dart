import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/data/trip_outcome_snooze_storage.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

/// "다녀오셨나요?" 알림을 눌러 들어오면 **그 알림의 여행**을 묻는다.
///
/// 예전에는 홈과 같은 규칙(가장 오래된 · 오늘 미루지 않은 여행 하나)을 써서
/// 두 가지가 어긋났다 — 미뤄 둔 여행의 알림을 누르면 아무 일도 없었고, 밀린
/// 여행이 둘이면 알림과 다른 여행을 물었다.
void main() {
  Map<String, dynamic> raw(int id, String region, int endDay) => {
    'courseId': id,
    'regionName': region,
    'travelDate': '2026-09-${(endDay - 1).toString().padLeft(2, '0')}',
    'travelEndDate': '2026-09-${endDay.toString().padLeft(2, '0')}',
    'consumedLeaveDays': 2,
  };

  Future<void> pump(
    WidgetTester tester, {
    required List<Map<String, dynamic>> pending,
    required int notificationCourseId,
    Set<int> snoozedToday = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseRepositoryProvider.overrideWithValue(_Repo(pending)),
          tripOutcomeSnoozeProvider.overrideWithValue(_Snooze(snoozedToday)),
          myLeaveProvider.overrideWith(
            (ref) async => const MyLeave(
              totalDays: 30,
              usedDays: 7,
              remainingDays: 23,
              usages: [],
            ),
          ),
          leaveUsagesProvider.overrideWith((ref) async => const <LeaveUsage>[]),
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

  testWidgets('오늘 미뤄 둔 여행이라도 그 알림을 누르면 묻는다', (tester) async {
    // 홈에서 '나중에 할게요'를 누른 뒤 알림을 눌렀다 — 예전에는 아무 일도 없었다
    await pump(
      tester,
      pending: [raw(7, '정선', 10)],
      notificationCourseId: 7,
      snoozedToday: {7},
    );
    expect(find.textContaining('정선'), findsWidgets);
    expect(find.textContaining('다녀오셨나요?'), findsOneWidget);
  });

  testWidgets('밀린 여행이 둘이면 알림이 가리킨 여행을 묻는다', (tester) async {
    // 강릉이 더 오래됐다 — 예전에는 정선 알림을 눌러도 강릉을 물었다
    await pump(
      tester,
      pending: [raw(3, '강릉', 5), raw(7, '정선', 10)],
      notificationCourseId: 7,
    );
    expect(find.textContaining('정선'), findsWidgets);
    expect(find.textContaining('강릉'), findsNothing);
  });

  testWidgets('이미 답한 여행의 알림이면 묻지 않는다 — 다른 여행도 꺼내지 않는다', (tester) async {
    // 알림은 목록에 남는다. 다시 눌러도 조용해야 하고, 엉뚱한 여행을 묻지 않는다
    await pump(tester, pending: [raw(3, '강릉', 5)], notificationCourseId: 7);
    expect(find.textContaining('다녀오셨나요?'), findsNothing);
  });
}

class _Repo implements CourseRepository {
  _Repo(this.pending);
  final List<Map<String, dynamic>> pending;

  @override
  Future<({List<Map<String, dynamic>> trips, double? remainingDays})>
  pendingTrips() async => (trips: pending, remainingDays: 23.0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snooze implements TripOutcomeSnoozeStorage {
  _Snooze(this.snoozed);
  final Set<int> snoozed;

  @override
  Future<bool> isSnoozedToday(int courseId, DateTime today) async =>
      snoozed.contains(courseId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
