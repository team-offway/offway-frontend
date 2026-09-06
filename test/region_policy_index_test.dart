import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/policy/data/region_policies_provider.dart';
import 'package:offway/features/policy/domain/region_benefit.dart';

/// 한 지역의 혜택 전부 — 서버는 대표 하나만 주므로 앱이 정책 상세를 모아
/// 지역별로 뒤집는다.
void main() {
  Map<String, dynamic> policy(
    int id,
    String name,
    String badge, {
    Map<String, String?>? period,
    List<int> regions = const [],
  }) => {
    'id': id,
    'type': 'T$id',
    'name': name,
    'badgeText': badge,
    'period': period,
    'applyUrl': null,
    'regions': [
      for (final r in regions) {'regionId': r, 'name': '지역$r'},
    ],
  };

  final today = DateTime(2026, 9, 6);

  group('buildRegionPolicyIndex', () {
    test('정책의 지역 목록을 지역별로 뒤집는다', () {
      final index = buildRegionPolicyIndex([
        policy(1, '반값여행', '여행경비 50% 환급', regions: [15, 16]),
        policy(3, '디지털관광주민증', '관광지 입장 할인', regions: [15, 16, 17]),
      ], today);

      expect(index.keys, unorderedEquals(['15', '16', '17']));
      expect(index['15']!.map((b) => b.policyId), [1, 3]);
      expect(index['17']!.map((b) => b.policyId), [3]);
      expect(index['15']!.first.policyName, '반값여행');
      expect(index['15']!.first.text, '여행경비 50% 환급');
    });

    test('기간이 끝난 정책은 빼고, 기간이 없는 정책은 상시다', () {
      // 정책 상세의 지역 목록은 기간을 안 거른다 — 8월에 끝난 숙박세일이
      // 9월 카드에 "+1"로 남으면 안 된다
      final index = buildRegionPolicyIndex([
        policy(
          2,
          '숙박세일',
          '숙박 할인',
          period: {'start': '2026-06-11', 'end': '2026-08-31'},
          regions: [15],
        ),
        policy(
          1,
          '반값여행',
          '환급',
          period: {'start': '2026-04-07', 'end': '2026-11-30'},
          regions: [15],
        ),
        policy(3, '주민증', '할인', period: null, regions: [15]),
      ], today);

      expect(index['15']!.map((b) => b.policyId), [1, 3]);
    });

    test('시작 전 정책도 뺀다 — 끝 날짜 당일은 유효하다', () {
      final index = buildRegionPolicyIndex([
        policy(
          4,
          '겨울',
          '스키',
          period: {'start': '2026-12-01', 'end': null},
          regions: [15],
        ),
        policy(
          5,
          '오늘까지',
          '마감',
          period: {'start': null, 'end': '2026-09-06'},
          regions: [15],
        ),
      ], today);

      expect(index['15']!.map((b) => b.policyId), [5]);
    });

    test('뱃지 문구나 id가 없는 정책은 넣지 않는다', () {
      final index = buildRegionPolicyIndex([
        {
          ...policy(1, '이름', ''),
          'regions': [
            {'regionId': 15},
          ],
        },
        {
          ...policy(1, '이름', '문구'),
          'id': null,
          'regions': [
            {'regionId': 15},
          ],
        },
      ], today);
      expect(index, isEmpty);
    });
  });

  group('benefitsForCard', () {
    final index = buildRegionPolicyIndex([
      policy(1, '반값여행', '여행경비 50% 환급', regions: [15]),
      policy(3, '주민증', '관광지 입장 할인', regions: [15]),
    ], today);

    test('서버가 준 대표가 맨 앞, 색인의 나머지가 뒤 — 대표는 안 겹친다', () {
      final card = {
        'id': '15',
        'name': '영월군',
        'benefit': {'text': '여행경비 50% 환급', 'policyId': 1},
      };
      final benefits = benefitsForCard(card, index);
      expect(benefits.map((b) => b.policyId), [1, 3]);
      // 대표는 서버 값 그대로다 — 색인 유무로 뱃지 문구가 달라지면 안 된다
      expect(benefits.first.policyName, isNull);
    });

    test('장소 카드는 regionId로 찾는다 — id는 장소 id다', () {
      final card = {
        'id': '126508',
        'placeName': '삼탄아트마인',
        'regionId': '15',
        'benefit': {'text': '여행경비 50% 환급', 'policyId': 1},
      };
      expect(benefitsForCard(card, index).map((b) => b.policyId), [1, 3]);
    });

    test('색인에 없는 지역은 대표 하나뿐이다', () {
      final card = {
        'id': '99',
        'benefit': {'text': '할인', 'policyId': 7},
      };
      expect(benefitsForCard(card, index).map((b) => b.policyId), [7]);
    });

    test('대표가 없으면 색인 순서대로다', () {
      expect(benefitsForCard({'id': '15'}, index).map((b) => b.policyId), [
        1,
        3,
      ]);
    });
  });

  test('RegionBenefit.parseList — 목록이 아니면 빈 목록', () {
    expect(RegionBenefit.parseList(null), isEmpty);
    expect(RegionBenefit.parseList('x'), isEmpty);
    expect(
      RegionBenefit.parseList([
        {'text': 'a', 'policyId': 1},
        {'text': ''},
        'b',
      ]).map((b) => b.text),
      ['a', 'b'],
    );
  });
}
