import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 갓 등록한 연차 내역에 붙는 'New' 칩 — 등록 후 24시간 (시안 Note).
///
/// 카드 맨 위, 날짜 글자 위에 놓인다. 시안 실측 — 배경 Label/Neutral,
/// 글자 Inverse/Label, 반경 6, 안쪽 7·4.
class LeaveNewChip extends StatelessWidget {
  const LeaveNewChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.labelNeutral,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'New',
        style: AppTypography.caption1Medium.copyWith(
          color: AppColors.inverseLabel,
        ),
      ),
    );
  }
}
