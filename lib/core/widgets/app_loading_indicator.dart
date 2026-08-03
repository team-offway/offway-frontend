import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 브랜드 마크가 도는 로딩 표시 (DS Loading 컴포넌트).
///
/// 시계방향으로 천천히 이어서 돈다. DS에는 4컷으로 그려져 있지만 그건 회전을
/// 예시한 것이고, 실제 움직임은 끊기지 않는다.
/// 뒤로 같은 마크를 조금씩 늦춰 옅게 깔아 잔상을 남긴다.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 48});

  final double size;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  /// 한 바퀴 도는 데 걸리는 시간
  static const _cycle = Duration(milliseconds: 7000);

  /// 본체 뒤에 남는 잔상 수
  static const _trailCount = 3;

  /// 잔상 사이의 각도 간격 (한 바퀴 대비 비율 · 0.014 ≈ 5°)
  static const _trailGap = 0.014;

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
    // SVG는 한 번만 만들어 잔상까지 같은 위젯을 재사용한다
    final mark = SvgPicture.asset(
      'assets/icons/ic_loading_mark.svg',
      width: widget.size,
      height: widget.size,
    );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 먼 잔상부터 그려 본체가 맨 위에 오게 한다
          for (var i = _trailCount; i >= 1; i--)
            _RotatingMark(
              controller: _controller,
              offsetTurns: -_trailGap * i,
              // 본체에 가까울수록 진하게 — 꼬리가 서서히 사라지도록
              opacity: 0.8 * (1 - i / (_trailCount + 1)),
              child: mark,
            ),
          _RotatingMark(controller: _controller, child: mark),
        ],
      ),
    );
  }
}

/// 컨트롤러를 따라 도는 마크 한 장. [offsetTurns]만큼 뒤처져 잔상이 된다.
class _RotatingMark extends StatelessWidget {
  const _RotatingMark({
    required this.controller,
    required this.child,
    this.offsetTurns = 0,
    this.opacity = 1,
  });

  final Animation<double> controller;
  final Widget child;
  final double offsetTurns;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final turns = offsetTurns == 0
        ? controller
        : controller.drive(Tween(begin: offsetTurns, end: 1 + offsetTurns));
    final rotating = RotationTransition(turns: turns, child: child);
    return opacity == 1 ? rotating : Opacity(opacity: opacity, child: rotating);
  }
}
