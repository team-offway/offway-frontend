import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_namer.dart';

/// 행정구역명을 부르는 이름으로 다듬는 규칙을 고정한다.
///
/// 이 값이 서버로 가서(core #382) 자차 카드의 `○○에서 출발`이 된다 —
/// 다듬기가 어긋나면 저장된 코스마다 어색한 이름이 박제된다.
void main() {
  group('시·군이 있으면 그것이 이름이다', () {
    test('성남시 → 성남', () {
      expect(shortOriginName(locality: '성남시', administrativeArea: '경기도'), '성남');
    });

    test('정선군 → 정선', () {
      expect(
        shortOriginName(locality: '정선군', administrativeArea: '강원특별자치도'),
        '정선',
      );
    });

    test('두 글자 이름은 접미로 보지 않는다', () {
      // '시'가 이름의 일부일 수 있다 — 떼면 한 글자가 남아 부를 수 없다
      expect(shortOriginName(locality: '구리'), '구리');
    });
  });

  group('없을 때만 시·도로 물러난다', () {
    test('서울특별시 → 서울', () {
      // 광역시는 iOS가 locality를 비워 보내는 일이 있다
      expect(shortOriginName(administrativeArea: '서울특별시'), '서울');
    });

    test('부산광역시 → 부산', () {
      expect(shortOriginName(administrativeArea: '부산광역시'), '부산');
    });

    test('세종특별자치시 → 세종', () {
      // '특별시'가 먼저 물면 '세종특별자치'가 남는다 — 긴 접미부터 본다
      expect(shortOriginName(administrativeArea: '세종특별자치시'), '세종');
    });

    test('제주특별자치도 → 제주', () {
      expect(shortOriginName(administrativeArea: '제주특별자치도'), '제주');
    });

    test('경기도는 그대로 둔다', () {
      // '경기'로 자르면 어색하고, '경상북도'를 '경상북'으로 만드는 규칙이 된다
      expect(shortOriginName(administrativeArea: '경기도'), '경기도');
    });
  });

  group('빈 값', () {
    test('둘 다 없으면 null — 이름 없이 보낸다', () {
      expect(shortOriginName(), isNull);
    });

    test('공백뿐이면 없는 것이다', () {
      expect(shortOriginName(locality: '  ', administrativeArea: ''), isNull);
    });
  });
}
