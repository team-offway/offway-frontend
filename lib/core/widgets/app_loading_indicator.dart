import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 브랜드 마크가 도는 로딩 표시 (DS Loading 컴포넌트).
///
/// 디자인이 90°씩 끊어지는 4프레임으로 정의돼 있어 부드럽게 돌리지 않고
/// 단계별로 튀도록 맞춘다.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 48});

  final double size;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  static const _frameCount = 4;
  static const _cycle = Duration(milliseconds: 800);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 연속값을 4단계로 끊어 프레임처럼 보이게 한다
        final step = (_controller.value * _frameCount).floor() % _frameCount;
        return Transform.rotate(
          angle: step * (2 * math.pi / _frameCount),
          child: child,
        );
      },
      child: SvgPicture.asset(
        'assets/icons/ic_loading_mark.svg',
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
