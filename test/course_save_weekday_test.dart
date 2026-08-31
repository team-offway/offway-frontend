import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/trip_date_range_picker.dart';
import 'package:offway/features/course/presentation/course_save_date_screen.dart';
import 'package:offway/features/course_wizard/presentation/calendar_screen.dart'
    show tripConsumedLeaveProvider;

/// 위저드에서 '목금토'로 만든 코스를 담을 때, 캘린더가 그 요일만 열고
/// 셋 중 무엇을 눌러도 **목요일**로 시작하는지 고정한다.
///
/// 요일을 안 지키면 코스와 날짜가 어긋난다 — 목금토로 짠 일정을 금토일에
/// 붙이면 첫날 일정이 금요일에 놓인다.
void main() {
  /// 이 달에서 [weekday] 요일이면서 오늘 이후인 첫 날짜
  DateTime firstWeekdayAfter(DateTime today, int weekday) {
    final delta = (weekday - today.weekday + 7) % 7;
    return DateTime(
      today.year,
      today.month,
      today.day + (delta == 0 ? 7 : delta),
    );
  }

  Future<TripDateRangePicker> pump(
    WidgetTester tester, {
    required int travelDays,
    int? startWeekday,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 날짜를 고르면 서버에 차감 연차를 묻는다 — 덮지 않으면 그 요청
          // 타이머가 테스트가 끝날 때까지 남는다
          tripConsumedLeaveProvider.overrideWith((ref, arg) async => 2.0),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: CourseSaveDateScreen(
            travelDays: travelDays,
            startWeekday: startWeekday,
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<TripDateRangePicker>(find.byType(TripDateRangePicker));
  }

  group('고를 수 있는 요일', () {
    testWidgets('목금토 코스는 목·금·토만 연다', (tester) async {
      final picker = await pump(
        tester,
        travelDays: 3,
        startWeekday: DateTime.thursday,
      );

      expect(picker.allowedWeekdays, {
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      });
    });

    testWidgets('주말을 넘어가면 다시 월요일로 돈다', (tester) async {
      // 토·일·월 — 일요일(7) 다음은 월요일(1)이다
      final picker = await pump(
        tester,
        travelDays: 3,
        startWeekday: DateTime.saturday,
      );

      expect(picker.allowedWeekdays, {
        DateTime.saturday,
        DateTime.sunday,
        DateTime.monday,
      });
    });

    testWidgets('당일치기는 그 요일 하나만 연다', (tester) async {
      final picker = await pump(
        tester,
        travelDays: 1,
        startWeekday: DateTime.saturday,
      );

      expect(picker.allowedWeekdays, {DateTime.saturday});
    });

    testWidgets('요일 조건이 없으면 모든 날을 연다', (tester) async {
      // 캘린더에서 직접 날짜를 고른 코스는 이 화면을 거치지 않지만,
      // 연차만 고른 경우처럼 요일이 정해지지 않는 길도 있다
      final picker = await pump(tester, travelDays: 3);

      expect(picker.allowedWeekdays, isNull);
    });
  });

  group('누른 날을 시작 요일로 되돌린다', () {
    testWidgets('금요일을 눌러도 그 주 목요일이 된다', (tester) async {
      final picker = await pump(
        tester,
        travelDays: 3,
        startWeekday: DateTime.thursday,
      );
      final today = DateUtils.dateOnly(DateTime.now());
      final friday = firstWeekdayAfter(today, DateTime.friday);

      picker.onSelect(friday);
      await tester.pump();

      // 금요일 하루 앞이 목요일이다
      expect(find.text('${friday.month}.${friday.day - 1}'), findsNothing);
      final field = tester.widget<TripDateRangePicker>(
        find.byType(TripDateRangePicker),
      );
      expect(field.startDate?.weekday, DateTime.thursday);
    });

    testWidgets('목요일을 누르면 그대로 목요일이다', (tester) async {
      final picker = await pump(
        tester,
        travelDays: 3,
        startWeekday: DateTime.thursday,
      );
      final today = DateUtils.dateOnly(DateTime.now());
      final thursday = firstWeekdayAfter(today, DateTime.thursday);

      picker.onSelect(thursday);
      await tester.pump();

      final field = tester.widget<TripDateRangePicker>(
        find.byType(TripDateRangePicker),
      );
      expect(field.startDate, thursday);
    });

    testWidgets('요일 조건이 없으면 누른 날이 그대로 시작일이다', (tester) async {
      final picker = await pump(tester, travelDays: 3);
      final today = DateUtils.dateOnly(DateTime.now());
      final anyDay = DateTime(today.year, today.month, today.day + 5);

      picker.onSelect(anyDay);
      await tester.pump();

      final field = tester.widget<TripDateRangePicker>(
        find.byType(TripDateRangePicker),
      );
      expect(field.startDate, anyDay);
    });
  });

  group('경로', () {
    test('요일이 없으면 파라미터를 안 붙인다', () {
      expect(
        AppRoutes.courseSaveDatePath(travelDays: 3),
        '/course-save-date?days=3',
      );
    });

    test('요일이 있으면 함께 싣는다', () {
      expect(
        AppRoutes.courseSaveDatePath(travelDays: 3, startWeekday: 4),
        '/course-save-date?days=3&startWeekday=4',
      );
    });
  });
}
