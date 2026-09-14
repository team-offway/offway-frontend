import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 타이머 둘레에 흩어 둔 반짝임 — 내 연차·총 연차 화면이 함께 쓴다.
///
/// 에셋 원본은 `#3DC2FF`(Light Blue 60)다. [tone]을 주면 그 색으로 덮는다 —
/// 셋을 같은 농도로 두면 반짝임이 평평해 보여 하나만 한 단 옅게 쓴다.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, required this.size, this.tone});

  final double size;

  /// null이면 에셋 원본색을 그대로 쓴다
  final Color? tone;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/ic_star_four.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: tone == null ? null : ColorFilter.mode(tone!, BlendMode.srcIn),
  );
}
