import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course_wizard/presentation/candidates_screen.dart';

/// 후보지역 카드의 뱃지는 혜택이다 — 시안이 한산/인기(crowdLevel) 칩을 혜택
/// 칩으로 바꿨다. 홈 카드와 같은 첫 번째 혜택 문구를 쓴다.
void main() {
  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> candidates,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizardCandidatesProvider.overrideWith((ref) async => candidates),
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

  testWidgets('혜택이 여럿이면 +1이 붙고, 누르면 고르는 시트가 뜬다', (tester) async {
    // 추천 응답은 혜택을 목록으로 준다 — 홈과 달리 색인 없이 바로 그린다
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
    expect(find.text('+1'), findsOneWidget);

    // 카드가 테스트 화면 아래에 걸린다 — 보이게 올린 뒤 누른다
    await tester.ensureVisible(find.text('+1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    expect(find.text('영월군 · 강원특별자치도 혜택'), findsOneWidget);
    expect(find.text('관광지 입장 할인'), findsOneWidget);
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
}
