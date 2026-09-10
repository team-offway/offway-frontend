import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
