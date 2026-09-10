import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/region_name.dart';

/// 지역명 표기 — '정선군 여행'은 말맛이 어색해 접미사를 뗀다.
void main() {
  group('접미사를 뗀다', () {
    test('시·군·구를 뗀다', () {
      expect(shortRegionNameOf('공주시'), '공주');
      expect(shortRegionNameOf('정선군'), '정선');
      expect(shortRegionNameOf('영도구'), '영도');
    });

    test('긴 접미사를 먼저 본다', () {
      expect(shortRegionNameOf('세종특별자치시'), '세종');
      expect(shortRegionNameOf('강원특별자치도'), '강원');
      expect(shortRegionNameOf('부산광역시'), '부산');
    });

    test('떼면 한 글자만 남는 이름은 그대로 둔다', () {
      expect(shortRegionNameOf('중구'), '중구');
      expect(shortRegionNameOf('동구'), '동구');
    });

    test('접미사가 없으면 그대로', () {
      expect(shortRegionNameOf('제주'), '제주');
    });

    test('없으면 null', () {
      expect(shortRegionNameOf(null), isNull);
      expect(shortRegionNameOf('  '), isNull);
    });
  });

  group('여행 라벨', () {
    test('접미사를 떼고 여행을 붙인다', () {
      expect(regionTripLabel('공주시'), '공주 여행');
      expect(regionTripLabel('정선군'), '정선 여행');
    });

    test('한 글자만 남는 이름은 원래대로 붙인다', () {
      expect(regionTripLabel('중구'), '중구 여행');
    });

    test('지역이 없으면 null — 빈 "여행"을 만들지 않는다', () {
      expect(regionTripLabel(null), isNull);
      expect(regionTripLabel(''), isNull);
    });
  });
}
