import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';
import 'package:offway/features/region/presentation/widgets/category_chip.dart';

/// 홈 '이번달 추천 여행지' 더보기 — 홈 위 섹션이 장소 카드라 여기도 장소다.
///
/// 예전에는 지역 목록(`GET /regions`)을 보여줘서 홈에서 본 장소가 하나도
/// 없었다(QA). 서버에 장소 목록 API는 없고 홈 응답이 곧 전체라 그걸 편다.
void main() {
  const filters = [
    {'key': 'ALL', 'label': '전체'},
    {'key': 'SIGHT', 'label': '관광지'},
    {'key': 'STAY', 'label': '숙박'},
  ];

  /// 서버 장소 카드 두 장 — 관광지 하나, 숙박 하나
  final places = [
    toPlaceCardMap(
      const {
        'poiContentId': '126508',
        'name': '삼탄아트마인',
        'kind': 'SIGHT',
        'regionName': '정선군',
        'regionId': 7,
        'subtitle': '폐광촌에서 다시 태어난 마을',
      },
      filters: filters,
      regions: const [
        {'regionId': 7, 'name': '정선군 · 강원'},
      ],
    ),
    toPlaceCardMap(
      const {
        'poiContentId': '200',
        'name': '정선 게스트하우스',
        'kind': 'STAY',
        'regionName': '정선군',
        'regionId': 7,
      },
      filters: filters,
      regions: const [
        {'regionId': 7, 'name': '정선군 · 강원'},
      ],
    ),
  ];

  Widget app() => ProviderScope(
    overrides: [
      homeSnapshotProvider.overrideWith(
        (ref) async => HomeSnapshot(
          user: const {'nickname': '예빈'},
          regions: const [],
          places: places,
          filters: filters,
        ),
      ),
    ],
    child: const MaterialApp(home: RegionListScreen()),
  );

  testWidgets('홈의 장소 카드를 전부 편다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('삼탄아트마인'), findsOneWidget);
    expect(find.text('정선 게스트하우스'), findsOneWidget);
  });

  testWidgets('칩을 고르면 홈과 같은 규칙으로 거른다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('숙박'));
    await tester.pump();
    expect(find.text('정선 게스트하우스'), findsOneWidget);
    expect(find.text('삼탄아트마인'), findsNothing);

    // 다른 칩으로 옮기면 그쪽만 남는다
    await tester.tap(find.text('관광지'));
    await tester.pump();
    expect(find.text('삼탄아트마인'), findsOneWidget);
    expect(find.text('정선 게스트하우스'), findsNothing);
  });

  test('필터 규칙은 홈·더보기가 한 함수를 쓴다', () {
    final all = filterCardsByCategory(places, const {
      'key': 'ALL',
      'label': '전체',
    });
    expect(all, hasLength(2));
    final stay = filterCardsByCategory(places, const {
      'key': 'STAY',
      'label': '숙박',
    });
    expect(stay.single['placeName'], '정선 게스트하우스');
    expect(filterCardsByCategory(places, null), hasLength(2));
  });

  // 장소가 비어 지역 목록으로 폴백하는 경로는 widget_test의
  // '홈 더보기 → 추천 여행지 목록에서 카테고리로 필터한다'가 mock 지역으로 덮는다
}
