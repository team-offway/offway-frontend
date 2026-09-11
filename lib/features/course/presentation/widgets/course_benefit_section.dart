import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../policy/domain/region_benefit.dart';
import '../../../policy/presentation/region_benefit_card.dart';

/// 코스 아래에 그 지역 혜택을 다시 펴 보이는 자리 (시안 1482:53418).
///
/// 위 장소 목록에서 뱃지로 스친 혜택을, 코스를 다 훑고 내려온 자리에서
/// 카드로 한 번 더 보여준다 — 담을지 정하기 직전이라 "가면 뭘 받나"가
/// 결정에 붙는 자리다.
///
/// 카드는 지역 상세와 **같은 것**(`RegionBenefitCard`)을 쓴다. 시안 치수도
/// 같아서 새로 조립할 이유가 없다.
///
/// 혜택이 없으면 통째로 사라진다 — 구분선만 남으면 빈 칸을 띄운 꼴이 된다.
class CourseBenefitSection extends StatelessWidget {
  const CourseBenefitSection({super.key, required this.benefits});

  final List<RegionBenefit> benefits;

  /// 구분 띠 두께 — 시안 실측(선이 아니라 면이다)
  static const _bandHeight = 12.0;

  @override
  Widget build(BuildContext context) {
    if (benefits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 목록의 좌우 여백(20)을 거슬러 화면 폭을 꽉 채운다 — 시안의 구분은
        // 선 하나가 아니라 두께 12의 띠다.
        //
        // 높이를 `SizedBox`로 묶어 둔다. `OverflowBox`만 두면 세로로도
        // 끝없이 커지려 해서 목록 안에서 터진다
        SizedBox(
          height: _bandHeight,
          child: OverflowBox(
            maxWidth: double.infinity,
            child: SizedBox(
              height: _bandHeight,
              width: MediaQuery.sizeOf(context).width,
              child: const ColoredBox(color: AppColors.lineSolidAlternative),
            ),
          ),
        ),
        // 시안 실측: 띠 아래 36
        const SizedBox(height: 36),
        Text(
          '이 지역에서 누릴 수 있는 혜택',
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        // 시안 실측: 제목 프레임(26) 아래 16
        const SizedBox(height: 16),
        for (final (i, benefit) in benefits.indexed) ...[
          // 시안 실측: 카드 사이 10
          if (i > 0) const SizedBox(height: 10),
          RegionBenefitCard(benefit: benefit),
        ],
      ],
    );
  }
}
