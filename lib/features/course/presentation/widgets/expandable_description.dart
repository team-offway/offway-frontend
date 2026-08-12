import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 길면 접히는 소개글.
///
/// 시안: 기본은 [maxLines]줄까지만 보이고 말줄임표로 끊는다. 그 아래 가운데
/// 펼침 아이콘(∨)을 두고, 펼치면 전문이 보이며 아이콘이 ∧로 바뀐다.
///
/// **[maxLines]줄을 넘지 않는 짧은 글에는 아이콘을 그리지 않는다** — 눌러도
/// 달라질 게 없는 아이콘은 사용자를 헷갈리게 한다. 넘치는지 여부는 실제 폭에
/// 맞춰 재봐야 알 수 있어서 [LayoutBuilder]로 잰다.
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({
    super.key,
    required this.text,
    this.maxLines = 3,
  });

  final String text;
  final int maxLines;

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label1NormalRegular.copyWith(
      color: AppColors.labelNeutral,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(style, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              // 접힌 동안만 줄 수를 묶는다 — 펼치면 전문을 보여준다
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (overflows) ...[
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    label: _expanded ? '접기' : '더 보기',
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 24,
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 주어진 폭에서 [widget.maxLines]줄을 넘기는지
  bool _overflows(TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}
