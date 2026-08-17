import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 상단 바의 뒤로가기·닫기·공유처럼 아이콘만 있는 버튼.
///
/// 아이콘은 20~24px로 작지만 손가락은 그보다 굵다. 눌리는 범위를 44×44로
/// 넓혀 빗나가지 않게 하고, 스크린 리더가 읽을 이름도 함께 붙인다.
///
/// [asset]을 주면 DS 에셋을, 없으면 [icon]의 Material 아이콘을 그린다.
/// 닫기는 [AppIconButton.close]로 만들면 DS 에셋이 자동으로 붙는다.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 24,
    this.color = AppColors.labelNormal,
    this.asset,
  });

  /// 닫기 버튼 — DS 에셋(`ic_close.svg`)을 쓴다.
  ///
  /// 에셋이 Label/Alternative(61%)를 이미 품고 있어 색을 덧입히지 않는다.
  /// Material [Icons.close]는 획이 얇고 끝이 각져 시안과 다르다.
  const AppIconButton.close({
    super.key,
    required this.onTap,
    this.semanticLabel = '닫기',
    this.size = 24,
  }) : icon = Icons.close,
       color = AppColors.labelAlternative,
       asset = 'assets/icons/ic_close.svg';

  final IconData icon;
  final VoidCallback onTap;

  /// 화면에 보이지 않지만 스크린 리더가 읽어줄 버튼 이름
  final String semanticLabel;

  final double size;
  final Color color;

  /// DS SVG 경로. 주면 [icon] 대신 이걸 그린다
  final String? asset;

  /// 손가락으로 눌러 빗나가지 않는 최소 크기
  static const _minTapTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    final path = asset;
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
            child: path == null
                ? Icon(icon, size: size, color: color)
                : SvgPicture.asset(path, width: size, height: size),
          ),
        ),
      ),
    );
  }
}
