import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/course_wizard/presentation/candidates_screen.dart';

/// 후보지역을 찾는 동안 **로딩 화면이 뜬다**.
///
/// 위저드 통합 테스트에서는 이걸 못 잡는다 — GPS 조회를 걷어내며(core #591)
/// 남은 비동기가 목 호출뿐이라, 화면 전환이 끝날 때쯤 결과도 와 있다.
/// 여기서는 응답을 붙들어 로딩 상태를 그대로 세워 둔다.
void main() {
  testWidgets('추천을 기다리는 동안 안내를 보여준다', (tester) async {
    // 끝나지 않는 Future — 로딩 상태에서 멈춰 세운다
    final never =
        Completer<
          ({List<Map<String, dynamic>> regions, List<DataSource> sources})
        >();
    addTearDown(() {
      if (!never.isCompleted) {
        never.complete((
          regions: const <Map<String, dynamic>>[],
          sources: const <DataSource>[],
        ));
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizardRecommendProvider.overrideWith((ref) => never.future),
        ],
        child: const MaterialApp(home: CandidatesScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('여행지를 찾고 있어요'), findsOneWidget);
  });
}
