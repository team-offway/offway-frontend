import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    test('시안의 다섯 구간 그대로다 — 요일·총 일수를 날짜에서 계산한다', () {
      // 2027년 달력 기준. 요일이 틀리면 시안 문구와 어긋난다
      expect(kGoldenHolidays.map((h) => h.rangeLabel), [
        '10.2(토) – 10.11(월)',
        '2.5(금) – 2.14(일)',
        '5.1(토) – 5.9(일)',
        '9.11(토) – 9.16(목)',
        '2.5(금) – 2.9(화)',
      ]);
      // 개천절만 시안 목록('총 9일')을 안 따랐다 — 달력으로 10일이고 같은
      // 시안의 상단 카드도 '최대 10일'이다
      expect(kGoldenHolidays.map((h) => h.totalDays), [10, 10, 9, 6, 5]);
      expect(kGoldenHolidays.map((h) => h.leaveDays), [4, 4, 3, 1, 1]);
    });

    test('상단 카드 표기는 붙여 쓴다', () {
      expect(kGoldenHolidays.first.heroRangeLabel, '10.2(토)-10.11(월)');
    });
  });

  group('화면', () {
    testWidgets('첫 구간을 위에 크게, 아래에 다섯 줄을 그린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const GoldenHolidaysScreen()),
      );
      await tester.pump();

      expect(find.text('2027 황금연휴 알아보기'), findsOneWidget);
      expect(find.text('2027년 연차 황금 타이밍'), findsOneWidget);
      expect(find.text('10.2(토)-10.11(월)'), findsOneWidget);
      expect(find.text('연차 4일로 최대 10일까지 쉴 수 있어요'), findsOneWidget);
      expect(find.text('$kGoldenHolidayYear년 연차 쓰기 좋은 날'), findsOneWidget);
      // 설날은 길고 짧은 두 구간이 함께 있다(시안 2·5번)
      expect(find.text('개천절·한글날'), findsOneWidget);
      expect(find.text('노동절·어린이날'), findsOneWidget);
      expect(find.text('추석 연휴'), findsOneWidget);
      expect(find.text('설날 연휴'), findsNWidgets(2));
      expect(find.text('총 10일 연휴'), findsNWidgets(2));
      expect(find.text('사용 연차 1일'), findsNWidgets(2));
    });

    testWidgets('행마다 순번이 붙고, 이름이 구간보다 위다', (tester) async {
      // 시안 1534:44705 — 고른 순서가 곧 추천 순서다. 무슨 연휴인지 먼저
      // 읽히도록 이름을 구간 위로 올렸다
      tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: GoldenHolidaysScreen()));
      await tester.pumpAndSettle();

      final first = kGoldenHolidays.first;
      final name = tester.getRect(find.text(first.label));
      final range = tester.getRect(find.text(first.rangeLabel));
      expect(name.top, lessThan(range.top), reason: '이름이 위');

      for (var i = 1; i <= kGoldenHolidays.length; i++) {
        expect(find.text('$i'), findsWidgets, reason: '$i번 행의 순번');
      }

      // 시안 실측: 번호와 글 사이 20
      final number = tester.getRect(find.text('1').first);
      expect(name.left - number.right, closeTo(20, 0.5));
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
      // 버튼 꺾쇠는 시안의 16 기본형 — 12×24 Tight를 늘려 쓰면 크고 길쭉하다
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/ic_chevron_right_16.svg',
        ),
        findsOneWidget,
      );
      // VoiceOver로도 누를 수 있어야 한다 — 카드가 한 버튼으로 읽히고 탭 동작을 가진다
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(GoldenHolidayCard)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: '2027 황금연휴 알아보기 보기',
        ),
      );
      semantics.dispose();
      // 시안 순서: 버튼이 제목 위에, 제목이 소개 위에
      final button = tester.getTopLeft(find.text('자세히')).dy;
      final title = tester.getTopLeft(find.text('2027 황금연휴 알아보기')).dy;
      final desc = tester.getTopLeft(find.textContaining('샌드위치 연휴')).dy;
      expect(button, lessThan(title));
      expect(title, lessThan(desc));

      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();

      expect(find.text('$kGoldenHolidayYear년 연차 쓰기 좋은 날'), findsOneWidget);
    });
  });
}
