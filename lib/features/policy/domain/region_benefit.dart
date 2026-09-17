/// 지역·장소에 붙는 혜택 하나 (서버 `BenefitResponse`).
///
/// 홈·지역 상세·장소 상세가 **같은 모양**으로 받는다(core #418). 예전에는
/// 장소 상세만 문구 하나짜리 문자열이라 화면마다 다른 파서를 들었다.
class RegionBenefit {
  const RegionBenefit({
    required this.text,
    this.policyType,
    this.policyId,
    this.applyUrl,
    this.policyName,
    this.benefitDetail,
  });

  /// 혜택 목록(`benefits[]`) → 화면이 읽는 형태. 목록이 아니면 빈 목록이다
  static List<RegionBenefit> parseList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final item in raw) ?tryParse(item)];
  }

  /// 응답의 혜택 값 → 화면이 읽는 형태.
  ///
  /// **문자열도 받는다.** 장소 상세가 예전 계약(`"benefit": "숙박 할인"`)으로
  /// 오던 자리라, 서버가 되돌아가거나 캐시된 옛 응답이 와도 뱃지가 사라지지
  /// 않게 한다. 그때는 누를 것이 없으니 `policyId`가 비고 뱃지가 정적이 된다.
  static RegionBenefit? tryParse(Object? raw) {
    final text = switch (raw) {
      final String s => s,
      final Map<String, dynamic> m => m['text'] as String?,
      _ => null,
    };
    if (text == null || text.trim().isEmpty) return null;

    final map = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return RegionBenefit(
      text: text.trim(),
      policyType: map['policyType'] as String?,
      policyId: (map['policyId'] as num?)?.toInt(),
      applyUrl: map['applyUrl'] as String?,
      policyName: map['policyName'] as String?,
      benefitDetail: map['benefitDetail'] as String?,
    );
  }

  /// 뱃지에 그리는 문구 — "숙박 할인"
  final String text;

  /// 혜택 분류 키. 화면이 분류마다 다르게 그릴 때 문구를 비교하지 않게 한다
  final String? policyType;

  /// 눌렀을 때 열 정책 상세의 id. 없으면 뱃지를 누를 수 없다
  final int? policyId;

  /// 지자체 신청 페이지. **아직 안 적은 정책이 있어 null이 정상이다**(core #418)
  final String? applyUrl;

  /// 정책 이름('지역사랑 휴가지원(반값여행)'). 서버 혜택 값에는 없고, 앱이
  /// 정책 상세에서 모은 목록([RegionPolicyIndex])에만 실린다 — 고르는 시트가
  /// 뱃지 문구만으로는 무엇인지 알기 어려워 이름을 함께 보여준다
  final String? policyName;

  /// 한 줄 설명('숙박비의 50%를 최대 10만원까지'). [policyName]과 같은
  /// 자리에서 온다 — 혜택 카드가 이름 아래 그린다.
  ///
  /// **이 값이 있으면 카드가 정책 상세를 다시 부르지 않는다.** 색인이 이미
  /// 받아 둔 응답에서 온 값이라, 버리면 카드마다 같은 요청이 한 번씩 더 나갔다
  final String? benefitDetail;
}
