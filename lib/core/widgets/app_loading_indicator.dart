import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 브랜드 마크가 도는 로딩 표시 (DS Loading 컴포넌트).
///
/// 시계방향으로 45°씩 여덟 번에 나눠 딱딱 끊어 돈다 — 이어서 도는 것보다
/// '처리 중'이라는 신호가 또렷하다.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({super.key, this.size = 48});

  final double size;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator> {
  /// 한 칸(45°) 머무는 시간 — 여덟 칸이면 한 바퀴에 4초
  static const _step = Duration(milliseconds: 500);

  /// 한 바퀴를 나누는 칸 수
  static const _steps = 8;

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      if (mounted) setState(() => _index = (_index + 1) % _steps);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Transform.rotate(
        // 자연스럽게 미끄러지지 않도록 각도를 칸 단위로만 바꾼다
        angle: _index * 2 * math.pi / _steps,
        child: SvgPicture.asset(
          'assets/icons/ic_loading_mark.svg',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
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
