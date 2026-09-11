import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/region/domain/region_visit_metrics.dart';
import 'package:offway/features/course_wizard/presentation/candidates_screen.dart';

/// 후보지역 카드의 뱃지는 혜택이다 — 시안이 한산/인기(crowdLevel) 칩을 혜택
/// 칩으로 바꿨다. 홈 카드와 같은 첫 번째 혜택 문구를 쓴다.
void main() {
  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> candidates, {
    Map<String, dynamic>? policy,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizardCandidatesProvider.overrideWith((ref) async => candidates),
          if (policy != null)
            policyDetailProvider(
              policy['id'] as int,
            ).overrideWith((ref) async => policy),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CandidatesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('혜택이 있으면 혜택 칩이 붙는다', (tester) async {
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'benefit': {'text': '숙박비 30% 지원', 'policyId': 7},
      },
    ]);

    expect(find.text('숙박비 30% 지원'), findsOneWidget);
  });

  testWidgets('혜택이 여럿이면 전부 편다 — 카드가 넓어 접을 이유가 없다', (tester) async {
    // 홈은 카드가 좁아 `+2`로 접지만 이 화면은 줄바꿈으로 다 보인다(QA 9/9)
    await pump(tester, [
      {
        'id': '15',
        'name': '영월군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'benefit': {'text': '여행경비 50% 환급', 'policyId': 1},
        'benefits': [
          {'text': '여행경비 50% 환급', 'policyId': 1},
          {'text': '관광지 입장 할인', 'policyId': 3},
        ],
      },
    ]);

    expect(find.text('여행경비 50% 환급'), findsOneWidget);
    expect(find.text('관광지 입장 할인'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
  });

  testWidgets('혜택 칩을 누르면 고르는 시트를 건너뛰고 그 혜택 상세가 열린다', (tester) async {
    // 칩 하나가 곧 혜택 하나다 — 한 건짜리 목록을 고르게 하는 것은 군더더기다
    await pump(
      tester,
      [
        {
          'id': '15',
          'name': '영월군',
          'sido': '강원특별자치도',
          'description': '자차 약 2시간 소요',
          'benefits': [
            {'text': '여행경비 50% 환급', 'policyId': 1},
            {'text': '관광지 입장 할인', 'policyId': 3},
          ],
        },
      ],
      policy: const {
        'id': 3,
        'name': '관광지 입장 할인 지원',
        'benefitDetail': '도내 관광지 입장료 50% 할인',
      },
    );

    // 카드가 테스트 화면 아래에 걸린다 — 보이게 올린 뒤 누른다
    await tester.ensureVisible(find.text('관광지 입장 할인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('관광지 입장 할인'));
    await tester.pumpAndSettle();

    expect(find.text('관광지 입장 할인 지원'), findsOneWidget);
    expect(find.text('도내 관광지 입장료 50% 할인'), findsOneWidget);
    // 고르는 시트는 거치지 않는다
    expect(find.text('영월군 · 강원특별자치도 혜택'), findsNothing);
  });

  testWidgets('혜택이 없으면 뱃지 자리가 비고, 한산·인기 칩은 더 없다', (tester) async {
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
      },
    ]);

    expect(find.text('정선군 · 강원특별자치도'), findsOneWidget);
    for (final crowd in const ['한산', '보통', '인기']) {
      expect(find.text(crowd), findsNothing);
    }
  });

  testWidgets("'최근 인기 상승' 칩은 분홍이다 — 혜택 칩과 색으로 갈린다", (tester) async {
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'visitMetrics': RegionVisitMetrics.parse({
          'trend': {'rising': true, 'percent': 12},
        }),
      },
    ]);

    final chip = find.text('최근 인기 상승');
    expect(chip, findsOneWidget);
    expect(tester.widget<Text>(chip).style?.color, AppPalette.pink60);
    final box = tester.widget<Container>(
      find.ancestor(of: chip, matching: find.byType(Container)).first,
    );
    expect((box.decoration! as BoxDecoration).color, AppPalette.pink95);
  });

  testWidgets('혜택 칩에는 태그 아이콘이 붙고, 인기 상승 칩에는 안 붙는다', (tester) async {
    // 시안 1482:53577 — 혜택임을 한눈에 알리는 자리다
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'benefits': [
          {'text': '여행경비 50% 환급', 'policyId': 1},
          {'text': '디지털관광주민증', 'policyId': 2},
        ],
        'visitMetrics': RegionVisitMetrics.parse({
          'trend': {'rising': true, 'percent': 12},
        }),
      },
    ]);

    // 화면에는 다른 아이콘도 많다 — 태그 아이콘만 센다
    final tagIcon = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          '${w.bytesLoader}'.contains('assets/icons/ic_tag.svg'),
    );
    // 혜택 둘에만 붙는다 — 인기 상승 칩까지 셋이 아니다
    expect(tagIcon, findsNWidgets(2));
    for (final text in const ['여행경비 50% 환급', '디지털관광주민증']) {
      final chip = find
          .ancestor(of: find.text(text), matching: find.byType(Container))
          .first;
      expect(find.descendant(of: chip, matching: tagIcon), findsOneWidget);
    }
    final rising = find
        .ancestor(of: find.text('최근 인기 상승'), matching: find.byType(Container))
        .first;
    expect(find.descendant(of: rising, matching: tagIcon), findsNothing);
  });

  testWidgets('칩이 짧아 넷이 들어가도 한 줄에 셋까지만 놓는다', (tester) async {
    // 시안이 줄당 셋을 넘지 않는다 — `Wrap`은 폭이 남으면 넷도 밀어 넣는다
    tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const labels = ['체험 할인', '숙박 할인', '입장 무료', '교통 지원'];
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'benefits': [
          for (var i = 0; i < labels.length; i++)
            {'text': labels[i], 'policyId': i + 1},
        ],
      },
    ]);

    final tops = [for (final l in labels) tester.getRect(find.text(l)).top];
    expect(tops[0], tops[1]);
    expect(tops[1], tops[2]);
    expect(tops[3], greaterThan(tops[2]), reason: '넷째는 아래 줄로 내려간다');
    // 넷이 한 줄에 들어갈 폭은 남아 있었다 — 개수 규칙이 끊은 것이다
    final third = tester.getRect(find.text(labels[2]));
    expect(
      third.right + tester.getRect(find.text(labels[3])).width,
      lessThan(370),
    );
  });

  testWidgets('칩이 길면 셋이 되기 전에 폭에서 먼저 접힌다', (tester) async {
    // 시안(1482:53608)이 140·128 / 109·92 로 2+2 인 이유다
    tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const labels = ['여행경비 50% 환급', '디지털관광주민증', '숙박 추가할인'];
    await pump(tester, [
      {
        'id': '1',
        'name': '정선군',
        'sido': '강원특별자치도',
        'description': '자차 약 2시간 소요',
        'benefits': [
          for (var i = 0; i < labels.length; i++)
            {'text': labels[i], 'policyId': i + 1},
        ],
      },
    ]);

    final tops = [for (final l in labels) tester.getRect(find.text(l)).top];
    expect(tops[0], tops[1]);
    expect(tops[2], greaterThan(tops[1]), reason: '셋째는 폭이 모자라 내려간다');
    // 줄 간격은 시안대로 6 — 칩 높이 28 을 더해 34 만큼 벌어진다
    expect(tops[2] - tops[1], closeTo(34, 0.5));
  });
}
