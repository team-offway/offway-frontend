import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 옅은 Primary 면 위의 정보 뱃지 (사용 연차·D-day).
///
/// 내 코스 상세와 공유 코스가 같은 모양을 쓴다. 글자 크기만 화면마다 달라
/// [textStyle]로 받는다 — 기본은 내 코스 상세의 Label2 Bold.
class CourseInfoBadge extends StatelessWidget {
  const CourseInfoBadge({
    super.key,
    required this.label,
    this.iconAsset,
    this.textStyle = AppTypography.label2Bold,
  });

  final String label;
  final String? iconAsset;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset case final asset?) ...[
            SvgPicture.asset(
              asset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryNormal,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: textStyle.copyWith(color: AppColors.primaryNormal),
          ),
        ],
      ),
    );
  }
}
