import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/leave/domain/golden_holiday.dart';
import 'package:offway/features/leave/presentation/golden_holidays_screen.dart';
import 'package:offway/features/leave/presentation/widgets/golden_holiday_card.dart';

/// 황금연휴 — 홈 카드에서 들어가는 '연차 쓰기 좋은 날' (시안 18900:72317).
void main() {
  group('값', () {
    test('시안의 네 구간 그대로다 — 요일·총 일수를 날짜에서 계산한다', () {
      // 2027년 달력 기준. 요일이 틀리면 시안 문구와 어긋난다
      expect(kGoldenHolidays.map((h) => h.rangeLabel), [
        '10.2(토) – 10.11(월)',
        '9.11(토) – 9.19(일)',
        '5.1(토) – 5.9(일)',
        '2.5(금) – 2.9(화)',
      ]);
      // 5.1~5.9는 시안이 10일이라 적었지만 달력으로 9일이다 — 달력을 따른다
      expect(kGoldenHolidays.map((h) => h.totalDays), [10, 9, 9, 5]);
      expect(kGoldenHolidays.map((h) => h.leaveDays), [4, 2, 3, 1]);
    });

    test('상단 카드 표기는 붙여 쓴다', () {
      expect(kGoldenHolidays.first.heroRangeLabel, '10.2(토)-10.11(월)');
    });
  });

  group('화면', () {
    testWidgets('첫 구간을 위에 크게, 아래에 네 줄을 그린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const GoldenHolidaysScreen()),
      );
      await tester.pump();

      expect(find.text('2027 황금연휴 알아보기'), findsOneWidget);
      expect(find.text('2027년 연차 황금 타이밍'), findsOneWidget);
      expect(find.text('10.2(토)-10.11(월)'), findsOneWidget);
      expect(find.text('연차 4일로 최대 10일까지 쉴 수 있어요'), findsOneWidget);
      expect(find.text('연차 쓰기 좋은 날'), findsOneWidget);
      for (final label in const ['개천절·한글날', '추석 연휴', '노동절·어린이날', '설날 연휴']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('총 10일 연휴'), findsOneWidget);
      expect(find.text('총 9일 연휴'), findsNWidgets(2));
      expect(find.text('사용 연차 1일'), findsOneWidget);
    });
  });

  group('홈 카드', () {
    testWidgets("'자세히'를 누르면 황금연휴 화면이 열린다", (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: GoldenHolidayCard()),
          ),
          GoRoute(
            path: AppRoutes.goldenHolidays,
            builder: (_, _) => const GoldenHolidaysScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pump();

      expect(find.text('2027 황금연휴 알아보기'), findsOneWidget);
      expect(find.text('자세히'), findsOneWidget);
      // 시안 순서: 버튼이 제목 위에, 제목이 소개 위에
      final button = tester.getTopLeft(find.text('자세히')).dy;
      final title = tester.getTopLeft(find.text('2027 황금연휴 알아보기')).dy;
      final desc = tester.getTopLeft(find.textContaining('샌드위치 연휴')).dy;
      expect(button, lessThan(title));
      expect(title, lessThan(desc));

      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();

      expect(find.text('연차 쓰기 좋은 날'), findsOneWidget);
    });
  });
}
