import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// Day 1 · Day 2 … 를 알약 버튼으로 늘어놓는 탭.
/// 코스 추천 결과·저장한 코스 화면이 공유한다.
class CourseDayTabs extends StatelessWidget {
  const CourseDayTabs({
    super.key,
    required this.durationDays,
    required this.selectedDay,
    required this.onSelect,
  });

  final int durationDays;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var d = 1; d <= durationDays; d++) ...[
          if (d > 1) const SizedBox(width: 10),
          _DayTab(day: d, selected: selectedDay == d, onTap: () => onSelect(d)),
        ],
      ],
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // DS Category 칩 (Large) — 고른 날은 반전, 나머지는 테두리만
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.labelNeutral : null,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? null
              : Border.all(color: AppColors.lineNormalNeutral),
        ),
        child: Text(
          'Day $day',
          style: AppTypography.body2NormalMedium.copyWith(
            color: selected
                ? AppColors.inverseLabel
                : AppColors.labelAlternative,
          ),
        ),
      ),
    );
  }
}
