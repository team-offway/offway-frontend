import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/widgets/trip_date_range_picker.dart';
import 'package:offway/features/leave/presentation/leave_date_picker_screen.dart';

/// 연차 등록 달력은 **지난 날짜를 고를 수 있다** — 이미 쓴 연차를 적는 자리다.
///
/// 여행 달력(위저드)은 지난 날을 막는다. 같은 위젯이라 스위치로 가른다 —
/// 위저드가 그대로인지도 함께 잠근다.
void main() {
  final today = DateTime(2026, 9, 16);

  Future<List<DateTime>> pump(
    WidgetTester tester, {
    required bool allowPast,
    int pastMonthCount = 0,
  }) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripDateRangePicker(
            today: today,
            startDate: null,
            endDate: null,
            onSelect: picked.add,
            maxSpanDays: null,
            showTripLabels: false,
            allowPast: allowPast,
            pastMonthCount: pastMonthCount,
          ),
        ),
      ),
    );
    await tester.pump();
    return picked;
  }

  /// 오늘 달 안의 [day] — 다른 달에도 같은 숫자가 있어 달 제목 아래로 좁힌다
  Finder dayInThisMonth(int day) => find.descendant(
    of: find
        .ancestor(of: find.text('2026년 9월'), matching: find.byType(Column))
        .first,
    matching: find.text('$day'),
  );

  testWidgets('지난 날짜를 열면 눌러서 고를 수 있다', (tester) async {
    final picked = await pump(tester, allowPast: true);

    await tester.tap(dayInThisMonth(10));
    await tester.pump();

    expect(picked, [DateTime(2026, 9, 10)]);
  });

  testWidgets('열지 않으면 지난 날짜는 눌러도 반응이 없다 — 위저드 그대로', (tester) async {
    final picked = await pump(tester, allowPast: false);

    await tester.tap(dayInThisMonth(10), warnIfMissed: false);
    await tester.pump();

    expect(picked, isEmpty);
  });

  testWidgets('과거 달을 그려도 열었을 때는 오늘 달에서 시작한다', (tester) async {
    // 12달 전부터 그리면서 맨 위에서 시작하면, 열자마자 작년 달이 보인다.
    // 오늘 달이 첫 화면이어야 하고, 지난달은 위로 밀어야 나온다
    await pump(tester, allowPast: true, pastMonthCount: 12);

    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('2026년 8월'), findsNothing, reason: '위에 접혀 있어야 한다');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump();

    expect(find.text('2026년 8월'), findsOneWidget);
  });

  testWidgets('과거 달을 안 그리면 오늘 달이 맨 위다 — 위저드 그대로', (tester) async {
    await pump(tester, allowPast: false, pastMonthCount: 0);

    // 위로 밀어도 나올 달이 없다
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump();

    expect(find.text('2026년 8월'), findsNothing);
    expect(find.text('2026년 9월'), findsOneWidget);
  });

  testWidgets('연차 등록 달력은 지난 날짜를 열고 지난달까지 그린다', (tester) async {
    // 화면이 정말 스위치를 켜는지 — 공용 위젯만 고치고 화면이 안 켜면 그대로다
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LeaveDatePickerScreen())),
    );
    await tester.pump();

    final picker = tester.widget<TripDateRangePicker>(
      find.byType(TripDateRangePicker),
    );
    expect(picker.allowPast, isTrue);
    expect(picker.pastMonthCount, greaterThan(0));
  });
}
