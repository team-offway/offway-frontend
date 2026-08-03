import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 아이콘 하나에 한 줄 안내를 붙인 알림 행.
///
/// 캘린더 상단 배너와 스테퍼 경고처럼 "왜 여기까지만 되는지"를 짚는 자리에 쓴다.
/// [minHeight]로 자리를 잡아두면 문구가 나타났다 사라져도 주변이 출렁이지 않는다.
class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    super.key,
    required this.iconAsset,
    required this.message,
    required this.color,
    this.minHeight = 52,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final String iconAsset;
  final String message;

  /// 글자색. 아이콘은 원본 색을 그대로 쓴다.
  final Color color;

  final double minHeight;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // 고정 높이 대신 최소 높이 — 글자 배율을 키워도 넘치지 않는다
      constraints: BoxConstraints(minHeight: minHeight),
      color: backgroundColor,
      padding: padding,
      child: Row(
        children: [
          SvgPicture.asset(iconAsset, width: 24, height: 24),
          const SizedBox(width: 10),
          // 좁은 화면에서 문구가 아이콘을 밀어내지 않도록 남는 폭 안에 가둔다
          Expanded(
            child: Text(
              message,
              style: AppTypography.label2Medium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
