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
