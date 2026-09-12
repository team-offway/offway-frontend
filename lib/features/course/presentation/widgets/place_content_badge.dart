import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 장소의 성격을 한 줄로 짚는 뱃지 — '반려동물 동반' · '주말에 붐빔'
/// (시안 18991:86950, DS Content Badge).
///
/// 혜택 뱃지(`BenefitBadge`)와 달리 **누를 수 없다.** 분류를 알리는 자리라
/// 시각 위계가 한 단계 낮고, 그래서 브랜드색이 아니라 회색을 쓴다.
class PlaceContentBadge extends StatelessWidget {
  const PlaceContentBadge({super.key, required this.icon, required this.text});

  /// 앞에 붙는 아이콘 경로 — 없으면 글자만 그린다
  final String? icon;

  final String text;

  /// 시안 실측 — 패딩 8·5, 반경 8, 아이콘 16, 글자와 간격 4
  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  static const _radius = 8.0;
  static const _iconSize = 16.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.fillNormal,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final asset?) ...[
            SvgPicture.asset(
              asset,
              width: _iconSize,
              height: _iconSize,
              // 에셋의 fill-opacity를 걷어내 두었다 — 남겨 두면 이 색과
              // 곱해져 시안보다 옅어진다
              colorFilter: const ColorFilter.mode(
                AppColors.labelAlternative,
                BlendMode.srcIn,
              ),
              excludeFromSemantics: true,
            ),
            const SizedBox(width: _gap),
          ],
          Text(
            text,
            style: AppTypography.label2Medium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }
}
