import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_namer.dart';

/// 행정구역명을 부르는 이름으로 다듬는 규칙을 고정한다.
///
/// 이 값이 서버로 가서(core #382) 자차 카드의 `○○에서 출발`이 된다 —
/// 다듬기가 어긋나면 저장된 코스마다 어색한 이름이 박제된다.
void main() {
  group('실측 — iOS(CLGeocoder, ko_KR)가 실제로 주는 모양', () {
    // 2026-09-01 macOS CLGeocoder로 28곳을 잰 값 그대로다. 열은
    // (administrativeArea, subAdministrativeArea, locality) → 기대 이름.
    // 실기기에서 '서울특별'로 떴던 버그가 이 표 첫 줄이다
    const rows = <(String, String?, String?, String?, String)>[
      ('서울시청', '서울특별시', null, '서울특별시', '서울'),
      ('서울 강남', '서울특별시', null, '서울특별시', '서울'),
      ('부산', '부산광역시', null, '부산광역시', '부산'),
      ('대구', '대구광역시', null, '대구광역시', '대구'),
      ('인천', '인천광역시', null, '인천광역시', '인천'),
      ('광주', '광주광역시', null, '광주광역시', '광주'),
      ('대전', '대전광역시', null, '대전광역시', '대전'),
      ('울산', '울산광역시', null, '울산광역시', '울산'),
      ('세종', '세종특별자치시', null, '세종특별자치시', '세종'),
      ('경기 성남', '경기도', null, '성남시', '성남'),
      ('경기 수원', '경기도', null, '수원시', '수원'),
      ('경기 시흥', '경기도', null, '시흥시', '시흥'),
      ('경기 구리', '경기도', null, '구리시', '구리'),
      ('경기 양평군', '경기도', '양평군', null, '양평'),
      ('강원 정선군', '강원특별자치도', '정선군', null, '정선'),
      ('강원 춘천', '강원특별자치도', null, '춘천시', '춘천'),
      ('충북 괴산군', '충청북도', '괴산군', null, '괴산'),
      ('충남 공주', '충청남도', null, '공주시', '공주'),
      ('충남 예산군', '충청남도', '예산군', null, '예산'),
      ('전북 전주', '전북특별자치도', null, '전주시', '전주'),
      ('전남 완도군', '전라남도', '완도군', null, '완도'),
      ('경북 안동', '경상북도', null, '안동시', '안동'),
      ('경북 울릉군', '경상북도', '울릉군', null, '울릉'),
      ('경남 창원', '경상남도', null, '창원시', '창원'),
      ('제주시', '제주특별자치도', null, '제주시', '제주'),
      ('서귀포', '제주특별자치도', null, '서귀포시', '서귀포'),
      ('인천 옹진 백령도', '인천광역시', '옹진군', '인천광역시', '인천'),
      ('인천 강화군', '인천광역시', '강화군', '인천광역시', '인천'),
    ];

    for (final (place, admin, subAdmin, locality, expected) in rows) {
      test('$place → $expected', () {
        expect(
          shortOriginName(
            locality: locality,
            subAdministrativeArea: subAdmin,
            administrativeArea: admin,
          ),
          expected,
        );
      });
    }
  });

  group('시·도만 남았을 때', () {
    test('특별자치도는 접미를 뗀다', () {
      expect(shortOriginName(administrativeArea: '강원특별자치도'), '강원');
      expect(shortOriginName(administrativeArea: '제주특별자치도'), '제주');
    });

    test('경기도·충청북도는 그대로 둔다', () {
      // '경기'·'충청북'으로 자르는 규칙은 어색한 이름을 만든다
      expect(shortOriginName(administrativeArea: '경기도'), '경기도');
      expect(shortOriginName(administrativeArea: '충청북도'), '충청북도');
    });
  });

  group('구·읍·면·동은 부르는 단위가 아니다', () {
    test('구가 오면 시·도로 물러난다', () {
      expect(
        shortOriginName(locality: '강남구', administrativeArea: '서울특별시'),
        '서울',
      );
    });

    test('군 아래 읍이 subAdministrativeArea에 와도 건너뛴다', () {
      expect(
        shortOriginName(
          subAdministrativeArea: '정선읍',
          administrativeArea: '강원특별자치도',
        ),
        '강원',
      );
    });

    test('구만 있고 시·도가 없으면 null', () {
      expect(shortOriginName(locality: '강남구'), isNull);
    });
  });

  group('빈 값', () {
    test('전부 없으면 null — 이름 없이 보낸다', () {
      expect(shortOriginName(), isNull);
    });

    test('공백뿐이면 없는 것이다', () {
      expect(shortOriginName(locality: '  ', administrativeArea: ''), isNull);
    });

    test('두 글자 이름은 접미로 보지 않는다', () {
      // '시'가 이름의 일부일 수 있다 — 떼면 한 글자가 남아 부를 수 없다
      expect(shortOriginName(locality: '구리'), '구리');
    });
  });
}
