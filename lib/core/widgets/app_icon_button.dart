import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';

/// 상단 바의 뒤로가기·닫기·공유처럼 아이콘만 있는 버튼.
///
/// 아이콘은 20~24px로 작지만 손가락은 그보다 굵다. 눌리는 범위를 44×44로
/// 넓혀 빗나가지 않게 하고, 스크린 리더가 읽을 이름도 함께 붙인다.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 24,
    this.color = AppColors.labelNormal,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// 화면에 보이지 않지만 스크린 리더가 읽어줄 버튼 이름
  final String semanticLabel;

  final double size;
  final Color color;

  /// 손가락으로 눌러 빗나가지 않는 최소 크기
  static const _minTapTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _minTapTarget,
          height: _minTapTarget,
          child: Center(
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
