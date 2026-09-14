import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 위저드의 선택형 버튼 — 날짜 갈림길(STEP0)·이동수단·일정밀도가 함께 쓴다.
///
/// **세 화면의 시안이 같다.** 날짜 갈림길(1438:48908 · DS 17686:52746)과
/// 이동수단(DS 17742:62938)을 대조했더니 크기·색·서체가 전부 일치했다 —
/// 그래서 variant 없이 하나로 둔다.
///
/// 예전에는 화면마다 private `_OptionButton` 을 따로 두어 값이 갈렸다.
/// 날짜 갈림길은 높이·테두리·선택 서체가, 위저드 공통은 미선택 글자색이
/// 시안과 달랐다. 한쪽만 고치면 다른 쪽이 조용히 어긋나던 자리다.
class WizardOptionButton extends StatelessWidget {
  const WizardOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 시안 실측 — 폭 200, 높이 48, radius 12
  static const _width = 200.0;
  static const _minHeight = 48.0;
  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 글자 바깥의 빈 자리를 눌러도 골라진다
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _width,
        constraints: const BoxConstraints(minHeight: _minHeight),
        alignment: Alignment.center,
        // 가로 16은 시안(28)과 다르지만 그대로 둔다 — 폭이 200 고정이고
        // 글자가 가운데 정렬이라 화면에 드러나지 않는다
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // 고른 것은 배경을 비우고 테두리·글자를 브랜드색으로 세운다
          color: selected ? null : AppColors.fillNormal,
          borderRadius: BorderRadius.circular(_radius),
          border: selected ? Border.all(color: AppColors.primaryNormal) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: selected
              ? AppTypography.body1NormalBold.copyWith(
                  color: AppColors.primaryNormal,
                )
              // 미선택은 Medium · Label/Neutral(88%)이다. labelNormal
              // (불투명)로 두면 시안보다 진하다
              : AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelNeutral,
                ),
        ),
      ),
    );
  }
}
