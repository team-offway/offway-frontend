import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 코스 타임라인의 세로 점선 — 디자인 스펙(0.5 대시 + 4 간격, round cap) 그대로.
class DottedVerticalLine extends StatelessWidget {
  const DottedVerticalLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1.25,
      child: CustomPaint(painter: _DotsPainter(), size: Size.infinite),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lineNormal
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    // 0.5 길이 대시에 round cap을 얹으면 점으로 보인다 — 4.5 주기로 찍는다
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += 4.5) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}
