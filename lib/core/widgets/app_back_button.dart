import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 상단 바의 뒤로가기 — DS 쉐브론(Tight) 에셋을 쓴다.
///
/// Material 기본 아이콘은 굵기·여백이 DS와 달라 화면마다 다르게 보였다.
/// 아이콘은 12×24로 좁아 손가락이 빗나가기 쉬우므로 눌리는 범위는 44×44다.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onTap,
    // DS 상단 내비게이션 기준 — 진한 검정은 제목보다 튄다
    this.color = AppColors.labelAlternative,
    this.semanticLabel = '뒤로 가기',
  });

  final VoidCallback onTap;
  final Color color;
  final String semanticLabel;

  /// 손가락으로 눌러 빗나가지 않는 최소 크기
  static const _minTapTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    // GestureDetector만 쓰면 키보드·D-pad로는 이 버튼에 닿을 수 없다 —
    // IconButton이 포커스와 눌림 표시를 함께 맡는다
    return IconButton(
      onPressed: onTap,
      tooltip: semanticLabel,
      // 기본값은 Material 최소 크기(48)를 강제해 화면마다 위치가 4씩 밀린다
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size.square(_minTapTarget),
      ),
      constraints: const BoxConstraints.tightFor(
        width: _minTapTarget,
        height: _minTapTarget,
      ),
      icon: SvgPicture.asset(
        'assets/icons/ic_chevron_left.svg',
        width: 12,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
