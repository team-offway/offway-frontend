import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';
import 'package:offway/features/home/application/home_providers.dart';

/// 지역 목록 하단 — 출처 줄이 **고정**이라 다른 화면과 처리가 다르다(#300 후속).
///
/// 출처를 화면 아래 **고정**으로 두면 목록이 그 위에서 끝나 인디케이터 자리가
/// 빈 배경으로 남는다 — 그게 흰 띠로 보였다. 다른 화면(코스 확정·후보 지역)
/// 처럼 **목록의 마지막 항목**으로 넣어 함께 스크롤되게 한다.
void main() {
  const inset = 34.0;

  Widget wrap({required bool withSources}) => ProviderScope(
    overrides: [
      homeSnapshotProvider.overrideWith(
        (ref) async => HomeSnapshot(
          user: const {'nickname': '영찬'},
          regions: const [],
          places: [
            for (var i = 0; i < 12; i++)
              {
                'name': '장소$i',
                'regionName': '가평군',
                'sido': '경기도',
                'subtitle': '설명',
              },
          ],
          sources: withSources
              ? const [DataSource(key: 'kto', label: '한국관광공사')]
              : const [],
        ),
      ),
    ],
    child: const MediaQuery(
      data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
      child: MaterialApp(home: RegionListScreen()),
    ),
  );

  Future<void> pump(WidgetTester tester, {bool withSources = true}) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(withSources: withSources));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('목록이 화면 끝까지 흐른다 — 아래에 빈 배경이 없다', (tester) async {
    await pump(tester);

    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    final scroll = tester.getRect(find.byType(CustomScrollView).first);

    expect(scroll.bottom, screenH, reason: '스크롤 영역이 인디케이터 아래까지 닿아야 그 자리가 안 빈다');
  });

  testWidgets('출처는 목록 끝에 따라온다 — 다른 화면과 같은 방식', (tester) async {
    await pump(tester);

    // 위에서는 아직 안 보인다. 끝까지 내려야 나온다
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('출처'), findsOneWidget);
  });

  testWidgets('끝까지 내리면 출처가 인디케이터 바로 위에 선다', (tester) async {
    await pump(tester);
    final screenH = tester.getSize(find.byType(MaterialApp)).height;

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();

    final text = tester.getRect(find.textContaining('출처').first);
    // 글자 아래로는 인디케이터(34)와 시안 여백(12)만 남는다
    expect(screenH - text.bottom, closeTo(46, 1));
  });

  testWidgets('출처가 없으면 그 줄은 아예 없다 — 빈 자리를 만들지 않는다', (tester) async {
    await pump(tester, withSources: false);

    expect(find.textContaining('출처'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
