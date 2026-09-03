import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/widgets/data_source_note.dart';
import 'package:offway/features/course/presentation/poi_detail_screen.dart';
import 'package:offway/features/course_wizard/presentation/candidates_screen.dart';

/// 출처 표기가 **화면까지 닿는가** (core #417).
///
/// 위젯만 테스트하면 리포지토리가 값을 안 실어 주는 경우를 못 잡는다. 응답은
/// 멀쩡해 보이는데 화면에서만 표기가 빠지고, 그게 규정 위반이다.
void main() {
  const kto = DataSource(key: 'KTO', label: '한국관광공사');

  testWidgets('장소 상세 — 응답의 출처를 화면 끝에 적는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiDetailProvider('X').overrideWith(
            (ref) async => {
              'title': '금수사',
              'address': '부산광역시 동구 홍곡로 100',
              '_sources': const [kto],
            },
          ),
        ],
        child: const MaterialApp(
          home: PoiDetailScreen(contentId: 'X', name: '금수사'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DataSourceNote), findsOneWidget);
    expect(find.text('출처: ©한국관광공사'), findsOneWidget);
  });

  testWidgets('장소 상세 — 출처를 안 주는 옛 서버에서도 화면은 뜬다', (tester) async {
    // 표기가 빠질 뿐 상세가 통째로 터지면 안 된다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiDetailProvider('X').overrideWith((ref) async => {'title': '금수사'}),
        ],
        child: const MaterialApp(
          home: PoiDetailScreen(contentId: 'X', name: '금수사'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('금수사'), findsOneWidget);
    expect(find.textContaining('출처'), findsNothing);
  });

  testWidgets('후보 지역 — 목록 끝에 출처를 적는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizardRecommendProvider.overrideWith(
            (ref) async => (
              regions: [
                {
                  'id': '1',
                  'name': '정선군',
                  'sido': '강원특별자치도',
                  'description': '자차 약 2시간 소요',
                },
              ],
              sources: const [kto],
            ),
          ),
        ],
        child: const MaterialApp(home: CandidatesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 카드 목록 끝이라 처음에는 화면 밖이다 — 스크롤해 닿는지 본다
    await tester.scrollUntilVisible(
      find.byType(DataSourceNote),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('출처: ©한국관광공사'), findsOneWidget);
  });
}
