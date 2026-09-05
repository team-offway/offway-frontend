import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/region/domain/region_visit_metrics.dart';
import 'package:offway/features/region/presentation/widgets/quietest_day_banner.dart';

/// 방문 지표 (core #438) — 한산한 요일·인기 추세.
///
/// **없는 값을 지어내지 않는 것**이 이 기능의 핵심이다. 서버는 재료가
/// 모자라면 비우고(요일당 40일 미만·격차 10% 미만·작년 치 없음), 화면은
/// 그때 그 줄을 지운다. 지어낸 숫자를 보고 갔다가 틀리면 우리가 내리는
/// 모든 숫자를 안 믿게 된다.
void main() {
  group('응답 파싱', () {
    test('한산한 요일과 추세를 함께 읽는다', () {
      final m = RegionVisitMetrics.parse(const {
        'quietestDay': {
          'dayOfWeek': 'TUESDAY',
          'label': '화요일',
          'percentLessThanOtherDays': 30,
        },
        'trend': {'percent': 40, 'rising': true},
      });

      expect(m.quietestDay?.label, '화요일');
      expect(m.quietestDay?.percentLessThanOtherDays, 30);
      expect(m.trend?.percent, 40);
      expect(m.trend?.rising, isTrue);
      expect(m.isEmpty, isFalse);
    });

    test('객체는 있고 안이 비면 빈 지표다', () {
      // 서버가 "객체는 항상 있고 안의 두 값이 각각 null 일 수 있다"고 못박았다
      final m = RegionVisitMetrics.parse(const {
        'quietestDay': null,
        'trend': null,
      });

      expect(m.quietestDay, isNull);
      expect(m.trend, isNull);
      expect(m.isEmpty, isTrue);
    });

    test('없거나 모양이 다르면 빈 지표다 — 옛 서버에서도 안 죽는다', () {
      expect(RegionVisitMetrics.parse(null).isEmpty, isTrue);
      expect(RegionVisitMetrics.parse('아무 값').isEmpty, isTrue);
    });

    test('한글 라벨이 없으면 요일을 그리지 않는다', () {
      // 서버가 한글을 든다 — 요일 코드로 앱이 한글을 지으면 두 곳이 갈린다
      expect(QuietestDay.tryParse(const {'dayOfWeek': 'TUESDAY'}), isNull);
      expect(
        QuietestDay.tryParse(const {'dayOfWeek': 'TUESDAY', 'label': ' '}),
        isNull,
      );
    });

    test('격차를 모르면 null이다 — 0으로 채우지 않는다', () {
      // 0을 넣으면 안내에 "약 0% 적어요"가 측정값처럼 뜬다.
      // 요일은 알지만 격차를 모르는 것이 사실이다
      final noPercent = QuietestDay.tryParse(const {'label': '화요일'});
      expect(noPercent?.label, '화요일');
      expect(noPercent?.percentLessThanOtherDays, isNull);
    });

    test('숫자가 아닌 격차가 와도 안 죽는다', () {
      // as num? 캐스트로 두면 여기서 예외가 올라가 화면이 통째로 빈다
      final odd = QuietestDay.tryParse(const {
        'label': '화요일',
        'percentLessThanOtherDays': '삼십',
      });
      expect(odd?.label, '화요일');
      expect(odd?.percentLessThanOtherDays, isNull);
    });

    test('rising이 거짓인 것과 trend가 없는 것은 다르다', () {
      // 앞은 "재 보니 안 늘었다", 뒤는 "아직 잴 수 없다"
      final flat = PopularityTrend.tryParse(const {
        'percent': -5,
        'rising': false,
      });
      expect(flat, isNotNull);
      expect(flat!.rising, isFalse);
      expect(PopularityTrend.tryParse(null), isNull);
    });

    test('증감률에 부호를 붙인다 — 방향이 숫자에서 읽힌다', () {
      expect(
        const PopularityTrend(percent: 40, rising: true).percentLabel,
        '+40%',
      );
      expect(
        const PopularityTrend(percent: -12, rising: false).percentLabel,
        '-12%',
      );
    });
  });

  group('한산한 날 배너', () {
    Future<void> pump(WidgetTester tester, QuietestDay? day) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: QuietestDayBanner(quietestDay: day)),
          ),
        );

    testWidgets('요일과 문구를 보여준다', (tester) async {
      await pump(
        tester,
        const QuietestDay(label: '화요일', percentLessThanOtherDays: 30),
      );

      expect(find.textContaining('화요일'), findsOneWidget);
      expect(find.textContaining('가장 한산해요'), findsOneWidget);
    });

    testWidgets('값이 없으면 자리도 없다', (tester) async {
      await pump(tester, null);

      expect(tester.getSize(find.byType(QuietestDayBanner)), Size.zero);
    });

    testWidgets('격차를 모르면 그 문장을 뺀다', (tester) async {
      // "약 0% 적어요"를 띄우면 재 본 값처럼 읽힌다
      await pump(tester, const QuietestDay(label: '화요일'));

      await tester.tap(find.bySemanticsLabel('한산한 요일 안내'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0%'), findsNothing);
      expect(find.textContaining('한산해요'), findsWidgets);
      expect(find.text('출처 · 관광빅데이터'), findsOneWidget);
    });

    testWidgets('i를 누르면 근거와 출처가 뜬다', (tester) async {
      // 근거 없이 숫자만 보이면 어디까지 믿을지 판단할 수 없다
      await pump(
        tester,
        const QuietestDay(label: '화요일', percentLessThanOtherDays: 30),
      );

      await tester.tap(find.bySemanticsLabel('한산한 요일 안내'));
      await tester.pumpAndSettle();

      expect(find.textContaining('최근 1년간 방문객 데이터'), findsOneWidget);
      expect(find.textContaining('약 30% 적어요'), findsOneWidget);
      expect(find.text('출처 · 관광빅데이터'), findsOneWidget);
    });
  });
}
