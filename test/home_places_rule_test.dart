import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 홈 '이번달 추천 여행지'에 어떤 장소 카드를 보여주는가.
void main() {
  const withDesc = {
    'id': '1',
    'placeName': '삼탄아트마인',
    'description': '폐광촌에서 다시 태어난 마을',
    'categoryCounts': {'관광지': 1},
  };
  const noDesc = {
    'id': '2',
    'placeName': '정선 게스트하우스',
    'categoryCounts': {'숙박': 1},
  };
  const emptyDesc = {
    'id': '3',
    'placeName': '어느 식당',
    'description': '',
    'categoryCounts': {'맛집': 1},
  };
  const places = [withDesc, noDesc, emptyDesc];

  test("'전체'에서는 한 줄 소개가 있는 장소만 보여준다", () {
    expect(homePlacesForChip(places, null).map((p) => p['id']), ['1']);
    expect(
      homePlacesForChip(places, const {
        'key': 'ALL',
        'label': '전체',
      }).map((p) => p['id']),
      ['1'],
    );
  });

  test('카테고리를 고르면 소개가 없어도 그 갈래는 전부 보여준다', () {
    // 숙박·음식은 소개가 늦게 채워진다 — 고른 사람에게 빈 갈래를 보이면 안 된다
    expect(
      homePlacesForChip(places, const {
        'key': 'STAY',
        'label': '숙박',
      }).map((p) => p['id']),
      ['2'],
    );
    expect(
      homePlacesForChip(places, const {
        'key': 'FOOD',
        'label': '맛집',
      }).map((p) => p['id']),
      ['3'],
    );
  });

  group("'전체'의 앞자리는 관광지·체험이다", () {
    Map<String, dynamic> place(String id, String kind) => {
      'id': id,
      'placeName': '장소$id',
      'description': '소개',
      'kind': kind,
    };

    test('앞 8장을 관광지·체험으로 채우고 나머지는 뒤로', () {
      // 서버는 지역별로 관광지→숙박→체험→맛집 차례라 숙소·식당이 앞쪽에 섞인다
      final places = [
        place('1', 'SIGHT'),
        place('2', 'STAY'),
        place('3', 'EXPERIENCE'),
        place('4', 'FOOD'),
        for (var i = 5; i <= 12; i++) place('$i', 'SIGHT'),
        place('13', 'STAY'),
      ];

      final shown = homePlacesForChip(places, null).map((p) => p['id']);

      // 앞 8장 — 관광지·체험을 원래 차례대로 당긴다
      expect(shown.take(8), ['1', '3', '5', '6', '7', '8', '9', '10']);
      // 그 뒤는 원래 차례 그대로 — 남은 관광지도 여기서는 안 당긴다
      expect(shown.skip(8), ['2', '4', '11', '12', '13']);
    });

    test('관광지·체험이 8장이 안 되면 있는 만큼만 앞에 둔다', () {
      final places = [
        place('1', 'FOOD'),
        place('2', 'SIGHT'),
        place('3', 'STAY'),
        place('4', 'EXPERIENCE'),
      ];
      expect(homePlacesForChip(places, null).map((p) => p['id']), [
        '2',
        '4',
        '1',
        '3',
      ]);
    });

    test('소개 없는 관광지는 앞자리에 못 온다 — 거름망이 먼저다', () {
      final places = [
        place('1', 'FOOD'),
        {...place('2', 'SIGHT'), 'description': ''},
      ];
      expect(homePlacesForChip(places, null).map((p) => p['id']), ['1']);
    });

    test('종류를 모르는 카드(옛 서버)는 뒤로 간다', () {
      final places = [
        {...place('1', 'SIGHT')}..remove('kind'),
        place('2', 'EXPERIENCE'),
      ];
      expect(homePlacesForChip(places, null).map((p) => p['id']), ['2', '1']);
    });

    test('카테고리 칩을 고르면 원래 차례 그대로다 — 한 갈래뿐이라 앞세울 게 없다', () {
      final places = [
        {
          ...place('1', 'STAY'),
          'categoryCounts': const {'숙박': 1},
        },
        {
          ...place('2', 'SIGHT'),
          'categoryCounts': const {'관광지': 1},
        },
        {
          ...place('3', 'STAY'),
          'categoryCounts': const {'숙박': 1},
        },
      ];
      expect(
        homePlacesForChip(places, const {
          'key': 'STAY',
          'label': '숙박',
        }).map((p) => p['id']),
        ['1', '3'],
      );
    });

    test('서버 카드에서 종류 키를 그대로 든다', () {
      final card = toPlaceCardMap({
        'poiContentId': 1,
        'name': '삼탄아트마인',
        'kind': 'SIGHT',
        'subtitle': '폐광촌',
      });
      expect(card['kind'], 'SIGHT');
    });
  });
}
