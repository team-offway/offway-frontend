import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/widgets/data_source_note.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

/// 지역 목록 하단 — 출처 줄이 **고정**이라 다른 화면과 처리가 다르다(#300 후속).
///
/// 출처 줄이 **화면 맨 아래**다. 인디케이터 자리는 이 줄의 아래 여백이
/// 채운다 — SafeArea 로 잘라내면 그 자리가 배경으로 남아 흰 띠처럼 보인다.
/// 목록 위에 겹치면 글자가 카드 위에 떠 보여 안 된다.
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

  testWidgets('출처 줄이 화면 맨 아래에 붙는다 — 그 아래 빈 배경이 없다', (tester) async {
    await pump(tester);

    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    final note = tester.getRect(find.byType(DataSourceNote));

    expect(
      note.bottom,
      screenH,
      reason: '출처 줄이 인디케이터 자리까지 차지해야 그 아래가 배경으로 안 남는다',
    );
  });

  testWidgets('출처 글자는 인디케이터 위에 있다 — 가려지지 않는다', (tester) async {
    await pump(tester);

    final screenH = tester.getSize(find.byType(MaterialApp)).height;
    final text = tester.getRect(find.textContaining('출처').first);

    expect(
      screenH - text.bottom,
      greaterThanOrEqualTo(inset),
      reason: '글자 아래로 인디케이터만큼은 비어 있어야 한다',
    );
  });

  testWidgets('목록은 출처 줄 위에서 끝난다 — 글자를 가리지 않는다', (tester) async {
    await pump(tester);
    final noteTop = tester.getRect(find.byType(DataSourceNote)).top;

    await tester.drag(find.byType(GridView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    var last = 0.0;
    for (final e in find.byType(RegionCard).evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      if (r.bottom > last) last = r.bottom;
    }

    expect(last, lessThanOrEqualTo(noteTop), reason: '카드가 출처 위로 넘지 않는다');
  });

  testWidgets('출처가 없으면 그 줄은 아예 없다 — 빈 자리를 만들지 않는다', (tester) async {
    await pump(tester, withSources: false);

    expect(find.textContaining('출처'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
