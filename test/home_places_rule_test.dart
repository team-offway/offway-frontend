import 'package:flutter_test/flutter_test.dart';
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
}
