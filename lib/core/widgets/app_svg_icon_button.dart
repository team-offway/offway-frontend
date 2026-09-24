import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 상단 바의 SVG 아이콘 버튼 — 터치 영역 44×44, 아이콘 24.
///
/// 코스 확정·내 코스 상세의 편집·공유 버튼이 같은 DS 에셋을 쓴다. Material
/// 기본 아이콘은 모양·굵기가 달라 두 화면의 버튼이 서로 다르게 보였다.
/// [onTap]이 null이면 눌리지 않는다(링크를 발급하는 중 등).
class AppSvgIconButton extends StatelessWidget {
  const AppSvgIconButton({
    super.key,
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: SvgPicture.asset(asset, width: 24, height: 24)),
        ),
      ),
    );
  }
}
