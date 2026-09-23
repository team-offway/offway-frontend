import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/region_benefit.dart';
import 'policy_repository.dart';

// 정책을 읽는 쪽(묶음 읽기·원본 목록)은 리포지토리에 있다. 이 파일을 보던
// 곳이 그대로 쓰게 다시 내보낸다
export 'policy_repository.dart'
    show allPoliciesProvider, fetchPoliciesInBatches;

/// 지역 id(문자열) → 그 지역에서 지금 받을 수 있는 혜택들
typedef RegionPolicyIndex = Map<String, List<RegionBenefit>>;

/// 지역별 혜택 목록 — **앱이 정책 상세를 역으로 읽어 만든다.**
///
/// 한 지역에 정책이 여럿인 것이 기본이다(89곳 중 85곳이 둘 이상). 그런데
/// 홈·지역 상세 응답은 대표 혜택 **하나만** 준다. 서버를 안 고치고 "+1"을
/// 띄우려면 정책 상세(`GET /policies/{id}`)가 주는 "이 혜택이 되는 지역
/// 목록"을 모아 뒤집는 수밖에 없다.
///
/// **정책 목록 API가 없어 id를 1부터 읽는다** — [fetchPoliciesInBatches]가
/// 묶음으로 한꺼번에 띄운다. 정책은 손으로 검증해 넣는 표라 몇 건 안 되고
/// id가 이어진다. 404가 연달아 [_endAfterMisses]번 나오면 끝으로 본다.
/// 세션 동안 한 번만 읽는다.
///
/// TODO(server): 홈·지역 상세가 `benefits[]`를 실어 주면 색인은 필요 없다 —
/// [benefitsForCard]가 이미 `card['benefits']`를 먼저 본다. 다만 홈
/// (`home_screen.dart`)·지역 상세(`region_detail_screen.dart`)가 이 파일의
/// [benefitsForCard]·[regionPoliciesProvider]를 직접 쓰므로, 지울 때는 그 두
/// 화면에서 색인을 걷어내는 일이 함께 따른다.
final regionPoliciesProvider = FutureProvider<RegionPolicyIndex>(
  (ref) async => buildRegionPolicyIndex(
    await ref.watch(allPoliciesProvider.future),
    DateTime.now(),
  ),
  retry: (retryCount, error) => null,
);

/// 정책 상세들 → 지역별 혜택 목록. [today]에 유효한 정책만 넣는다.
///
/// 정책 상세의 지역 목록은 기간을 안 거른다(끝난 정책도 지역을 든다). 여기서
/// 거르지 않으면 8월에 끝난 숙박세일이 9월 카드에 "+1"로 남는다
RegionPolicyIndex buildRegionPolicyIndex(
  List<Map<String, dynamic>> policies,
  DateTime today,
) {
  final index = <String, List<RegionBenefit>>{};
  for (final policy in policies) {
    if (!_activeOn(policy['period'], today)) continue;
    final benefit = RegionBenefit(
      text: (policy['badgeText'] as String?)?.trim() ?? '',
      policyType: policy['type'] as String?,
      policyId: (policy['id'] as num?)?.toInt(),
      applyUrl: policy['applyUrl'] as String?,
      // 카드가 그릴 이름·설명을 **여기서 함께 싣는다.** 버리면 카드가 같은
      // 정책을 다시 불러야 한다 — 이미 이 응답에 들어 있는 값이다
      policyName: policy['name'] as String?,
      benefitDetail: policy['benefitDetail'] as String?,
    );
    if (benefit.text.isEmpty || benefit.policyId == null) continue;
    for (final region in (policy['regions'] as List?) ?? const []) {
      if (region is! Map<String, dynamic>) continue;
      final regionId = (region['regionId'] as num?)?.toString();
      if (regionId == null) continue;
      index.putIfAbsent(regionId, () => []).add(benefit);
    }
  }
  return index;
}

/// `period: {start, end}` — 둘 다 없으면 상시(디지털관광주민증)
bool _activeOn(Object? period, DateTime today) {
  if (period is! Map<String, dynamic>) return true;
  final start = DateTime.tryParse(period['start'] as String? ?? '');
  final end = DateTime.tryParse(period['end'] as String? ?? '');
  final day = DateTime(today.year, today.month, today.day);
  if (start != null && day.isBefore(start)) return false;
  if (end != null && day.isAfter(end)) return false;
  return true;
}

/// 카드 하나가 뱃지에 쓸 혜택 목록 — **서버가 준 대표가 맨 앞**, 색인의
/// 나머지가 뒤에 온다. 대표를 앞에 두는 이유는 "+1"이 붙어도 뱃지 문구가
/// 서버 응답과 같아야 하기 때문이다 — 색인이 못 읽힌 날과 읽힌 날의 뱃지가
/// 달라지면 안 된다
List<RegionBenefit> benefitsForCard(
  Map<String, dynamic> card,
  RegionPolicyIndex index,
) {
  // 서버가 목록째 주면 그것이 답이다 — 색인은 대표 하나만 올 때의 보완이다.
  // 홈·지역 상세가 `benefits[]`를 싣기 시작하면 여기서 바로 그 값을 쓴다
  final served = RegionBenefit.parseList(card['benefits']);
  if (served.isNotEmpty) return served;
  final fromCard = RegionBenefit.tryParse(card['benefit']);
  // 장소 카드는 지역 id를 따로 든다(`id`는 장소 id다)
  final regionId =
      card['regionId']?.toString() ??
      (card['placeName'] == null ? card['id']?.toString() : null);
  final known = index[regionId] ?? const <RegionBenefit>[];
  // **대표에도 색인이 아는 이름·설명을 붙인다.** 지역 응답의 혜택 값에는 그
  // 두 칸이 없어, 안 붙이면 대표 카드만 정책 상세를 다시 부른다 — 색인 쪽만
  // 고친 #313 이 놓친 자리다(CodeRabbit 리뷰).
  //
  // 뱃지 문구와 신청 주소는 서버 값을 그대로 둔다 — 그쪽이 이 지역 기준이다
  final representative = fromCard?.mergedWith(
    known.where((b) => b.policyId == fromCard.policyId).firstOrNull,
  );
  final others = [
    for (final b in known)
      if (b.policyId != representative?.policyId) b,
  ];
  return [?representative, ...others];
}
