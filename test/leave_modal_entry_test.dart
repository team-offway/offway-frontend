import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/course/domain/pending_trip.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

/// "다녀오셨나요?" 모달이 뜨는 자리를 고정한다.
///
/// 시안에서 이 모달이 뜨는 곳은 **홈 진입**과 **그 알림을 눌렀을 때** 둘뿐이다.
/// 연차를 보러 그냥 들어온 사람에게까지 띄우면, 홈에서 '나중에 할게요'로 미룬
/// 사람이 연차 화면에 들어갈 때마다 같은 질문을 다시 받는다.
void main() {
  final trip = PendingTrip(
    courseId: 1,
    regionName: '정선',
    startDate: DateTime(2026, 7, 20),
    endDate: DateTime(2026, 7, 22),
    consumedLeaveDays: 3,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool fromNotification,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 물어볼 여행이 있다 — 조건은 갖춰 두고 진입 경로만 가른다
          pendingTripProvider.overrideWith((ref) async => trip),
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
          home: MyLeaveScreen(fromNotification: fromNotification),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('그냥 들어오면 모달이 뜨지 않는다', (tester) async {
    await pump(tester, fromNotification: false);
    expect(find.textContaining('다녀오셨나요?'), findsNothing);
  });

  testWidgets('알림을 눌러 들어오면 모달이 뜬다', (tester) async {
    await pump(tester, fromNotification: true);
    expect(find.textContaining('다녀오셨나요?'), findsOneWidget);
  });
}
