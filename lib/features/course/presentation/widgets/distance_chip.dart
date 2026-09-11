import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 장소와 장소 사이의 이동 거리 칩 — `14.2km`.
///
/// 코스 확정·내 코스 상세가 같은 모양을 따로 조립하고 있었다. 한쪽만 고치면
/// 같은 코스를 담기 전후로 칩이 달라 보인다.
///
/// **테두리 없는 회색 채움이다**(시안 18991:85155, QA 9/11). 예전에는 흰
/// 바탕에 선을 둘렀는데, 점선 동선 위에 놓이는 칩이라 선이 하나 더 겹쳐
/// 복잡했다.
class DistanceChip extends StatelessWidget {
  const DistanceChip({super.key, required this.meters});

  final int meters;

  /// 시안 실측 — 패딩 14·7, 반경 8, 글자 12
  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 7);
  static const _radius = 8.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(
        '${(meters / 1000).toStringAsFixed(1)}km',
        style: AppTypography.caption1Regular.copyWith(
          color: AppColors.labelAlternative,
        ),
      ),
    );
  }
}
