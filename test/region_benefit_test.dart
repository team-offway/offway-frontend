import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/policy/domain/region_benefit.dart';

/// 혜택 응답 파싱 — 서버가 문자열에서 객체로 바꾼 자리다(core #418).
void main() {
  test('객체를 그대로 읽는다 — 링크와 정책 id까지', () {
    final benefit = RegionBenefit.tryParse({
      'text': '숙박 할인',
      'policyType': 'STAY_FESTA',
      'policyId': 2,
      'applyUrl': 'https://ktostay.visitkorea.or.kr',
    });

    expect(benefit, isNotNull);
    expect(benefit!.text, '숙박 할인');
    expect(benefit.policyType, 'STAY_FESTA');
    expect(benefit.policyId, 2);
    expect(benefit.applyUrl, 'https://ktostay.visitkorea.or.kr');
  });

  test('옛 계약(문자열)도 뱃지는 그린다 — 누를 수만 없다', () {
    // 장소 상세가 문자열로 오던 자리다. 캐시된 옛 응답이 와도 상세가
    // 통째로 터지지 않고 뱃지가 남아야 한다
    final benefit = RegionBenefit.tryParse('숙박 할인');

    expect(benefit?.text, '숙박 할인');
    expect(benefit?.policyId, isNull);
  });

  test('신청 주소가 없어도 혜택은 성립한다', () {
    // 7대 혜택 중 넷이 아직 applyUrl을 안 채웠다(core #418 · #119)
    final benefit = RegionBenefit.tryParse({
      'text': '입장료 50% 할인',
      'policyId': 7,
    });

    expect(benefit?.applyUrl, isNull);
    expect(benefit?.policyId, 7);
  });

  test('없거나 빈 문구는 혜택이 아니다', () {
    expect(RegionBenefit.tryParse(null), isNull);
    expect(RegionBenefit.tryParse(''), isNull);
    expect(RegionBenefit.tryParse('   '), isNull);
    expect(RegionBenefit.tryParse(const {'text': null}), isNull);
    expect(RegionBenefit.tryParse(const {'text': ' '}), isNull);
    // 모양이 아예 다른 값이 와도 화면이 죽지 않는다
    expect(RegionBenefit.tryParse(42), isNull);
  });

  test('앞뒤 공백은 걷어낸다 — 뱃지가 한쪽으로 밀린다', () {
    expect(RegionBenefit.tryParse(' 숙박 할인 ')?.text, '숙박 할인');
  });
}
