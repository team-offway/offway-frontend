import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 브랜드 마크가 도는 로딩 표시 (DS Loading 컴포넌트).
///
/// 디자이너가 준 `Loading.svg`의 모션을 그대로 옮겼다.
/// 한 바퀴(2초)를 **90°씩 네 구간**으로 나누고, 각 구간을 `ease-out`으로
/// 돈다 — 훅 돌았다가 멎기를 반복해 '처리 중'이라는 신호가 또렷하다.
///
/// 예전에는 45°씩 여덟 칸을 타이머로 순간이동시켰다. 각도가 뚝뚝 끊겨
/// 시안의 감속이 살지 않았다.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 48});

  final double size;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  /// 한 바퀴에 걸리는 시간 — 시안 `animation: loading-spin 2s`
  static const _turn = Duration(seconds: 2);

  /// 한 바퀴를 나누는 구간 수 — 시안 keyframes가 0·25·50·75·100%다
  static const _steps = 4;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _turn,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.rotate(angle: _angleAt(_controller.value), child: child),
        // 회전만 바뀐다 — 매 프레임 SVG를 다시 만들지 않는다
        child: SvgPicture.asset(
          'assets/icons/ic_loading_mark.svg',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }

  /// 진행도(0~1)를 각도로. 구간 안에서만 `ease-out`으로 감속한다.
  ///
  /// 시안은 -360°에서 0°로 가지만 회전은 같은 자리를 도는 것이라
  /// 0°에서 시계방향으로 재도 결과가 같다.
  double _angleAt(double t) {
    final scaled = t * _steps;
    final step = scaled.floor(); // 몇 번째 구간인가 (0~3)
    final within = Curves.easeOut.transform(scaled - step);
    return (step + within) * 2 * math.pi / _steps;
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, required this.title});

  /// 무엇을 기다리는지 — 줄바꿈 포함 가능
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      // 시안은 블록이 화면 중앙보다 92 위에 있다. 아래 여백으로 밀면
      // 블록이 차지하는 높이까지 같이 늘어 좁은 화면에서 넘친다 —
      // 자리만 옮긴다
      child: Transform.translate(
        offset: const Offset(0, -92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingIndicator(),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headline1Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '잠시만 기다려주세요.',
              textAlign: TextAlign.center,
              style: AppTypography.body2NormalMedium.copyWith(
                color: AppColors.labelAssistive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
