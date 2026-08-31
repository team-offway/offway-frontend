import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 세로 점선 — 대시 길이에 round cap을 얹어 점으로 보이게 그린다.
///
/// 코스 타임라인(번호를 잇는 선)과 교통 카드(아이콘 아래로 흘리는 선)가
/// 굵기·간격을 달리 쓴다. 시안이 정한 값을 그대로 받는다.
class DottedVerticalLine extends StatelessWidget {
  const DottedVerticalLine({
    super.key,
    this.thickness = 1.25,
    this.dash = 0.5,
    this.gap = 4,
    this.color,
  });

  /// 교통 카드용 — 굵기 2에 간격 6 (`stroke-dasharray="0.5 6"`)
  const DottedVerticalLine.transit({super.key})
    : thickness = 2,
      dash = 0.5,
      gap = 6,
      color = AppColors.lineNormalNeutral;

  final double thickness;

  /// 점 하나의 길이 — round cap이 붙어 실제로는 [thickness]만 한 원으로 보인다
  final double dash;

  /// 점 사이 빈 길이
  final double gap;

  /// null이면 타임라인 기본색
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: thickness,
      child: CustomPaint(
        painter: _DotsPainter(
          thickness: thickness,
          dash: dash,
          gap: gap,
          color: color ?? AppColors.lineNormal,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({
    required this.thickness,
    required this.dash,
    required this.gap,
    required this.color,
  });

  final double thickness;
  final double dash;
  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    // 짧은 대시에 round cap을 얹으면 점으로 보인다
    final x = size.width / 2;
    final step = dash + gap;
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.thickness != thickness ||
      old.dash != dash ||
      old.gap != gap ||
      old.color != color;
}
