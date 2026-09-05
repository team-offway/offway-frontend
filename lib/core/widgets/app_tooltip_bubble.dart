import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';

/// 위쪽을 가리키는 말풍선 툴팁 (DS Tooltip/Tooltip · Position=Bottom).
///
/// 어떤 버튼이 무엇을 하는지 한 번 알려 주고 사라지는 자리다. 어두운 배경에
/// 흰 글씨라 화면 위에 떠 있어도 뒤 내용과 섞이지 않는다.
class AppTooltipBubble extends StatelessWidget {
  const AppTooltipBubble({super.key, required this.text});

  final String text;

  /// 시안 실측 — 화살표 20×8
  static const _arrowWidth = 20.0;
  static const _arrowHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // 글자만큼만 넓어진다 — stretch로 두면 부모 폭을 다 먹어 시안(191)과
      // 어긋나고, 화살표도 붙일 자리를 잃는다
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          // 시안: 화살표가 모서리에 딱 붙지 않고 8 안쪽이다
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CustomPaint(
            size: const Size(_arrowWidth, _arrowHeight),
            painter: const _ArrowPainter(),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 64, maxWidth: 256),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _bubbleColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.inverseLabel,
            ),
          ),
        ),
      ],
    );
  }

  /// 시안은 어두운 배경(88%) 위에 브랜드색을 5% 얹는다 — 그 둘을 미리 섞어
  /// 한 겹으로 칠한다. 두 겹을 그대로 쌓으면 화살표에서 경계가 비친다
  static final _bubbleColor = Color.alphaBlend(
    AppColors.primaryNormal.withValues(alpha: AppOpacity.o5),
    AppColors.inverseBackground.withValues(alpha: AppOpacity.o88),
  );
}

/// 위를 가리키는 삼각형 — 시안 화살표는 꼭짓점이 둥글다
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2 - 2, 1)
      // 꼭짓점만 살짝 굴린다 — 각지면 말풍선과 결이 다르다
      ..quadraticBezierTo(size.width / 2, -1, size.width / 2 + 2, 1)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTooltipBubble._bubbleColor);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
