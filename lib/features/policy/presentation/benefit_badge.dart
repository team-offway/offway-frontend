import 'package:flutter/material.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../domain/region_benefit.dart';
import 'policy_detail_sheet.dart';

/// 혜택 뱃지 — 누르면 정책 상세 시트가 올라온다.
///
/// 지역 카드·지역 상세·후보 지역·장소 상세가 **같은 값을 같은 모양으로**
/// 그린다(core #418). 예전에는 화면마다 같은 `Container`를 따로 조립해,
/// 후보 지역만 누를 수 있고 나머지는 정적인 상태가 굳어 있었다.
///
/// 색·모서리·탭 동작은 어디서나 같고 **크기만 시안대로 갈린다**([BenefitBadgeSize]).
class BenefitBadge extends StatelessWidget {
  const BenefitBadge({
    super.key,
    required this.benefit,
    this.size = BenefitBadgeSize.normal,
  });

  final RegionBenefit benefit;

  /// 놓이는 자리에 맞는 크기. 시안이 카드와 상세에서 다르게 잡았다
  final BenefitBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final policyId = benefit.policyId;
    return GestureDetector(
      // 카드 전체 탭(코스·지역)보다 안쪽이라 여기서 제스처를 먼저 받는다.
      // policyId가 없으면 열 상세가 없어 탭을 막는다 — 눌러도 아무 일도
      // 안 일어나는 자리를 남기지 않는다
      onTap: policyId == null
          ? null
          : () => showPolicyDetailSheet(context, policyId),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: size.padding,
        decoration: BoxDecoration(
          // 혜택 뱃지는 브랜드색 8% 배경에 브랜드색 글자다(시안 Badge).
          // 회색(Fill/Normal)은 분류용 뱃지 색이라 혜택이 눈에 안 띈다
          color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
          borderRadius: BorderRadius.circular(size.radius),
        ),
        child: Text(
          benefit.text,
          style: size.textStyle.copyWith(color: AppColors.primaryNormal),
        ),
      ),
    );
  }
}

/// 뱃지가 놓이는 자리별 크기 — 시안 실측값이다.
enum BenefitBadgeSize {
  /// 홈·지역 목록의 좁은 카드 안
  card,

  /// 후보 지역 카드 — 카드보다 넓지만 상세보다는 좁다
  candidate,

  /// 장소 상세의 본문
  normal,

  /// 지역 상세 — 지역명 바로 아래라 본문 중 가장 크다
  regionDetail;

  EdgeInsets get padding => switch (this) {
    card => const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    candidate => const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    normal => const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    regionDetail => const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  };

  TextStyle get textStyle => switch (this) {
    card => AppTypography.caption2Medium,
    candidate || normal => AppTypography.caption1Medium,
    // 가이드는 Label 2/Medium(13·w500)이다 — w600은 더 두껍다
    regionDetail => AppTypography.label2Medium,
  };

  double get radius => this == regionDetail ? 8 : 6;
}
