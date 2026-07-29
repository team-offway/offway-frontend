import 'package:flutter/material.dart';

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _textSecondary = Color(0xFF686F7E);
const _actionGray = Color(0xFFE9E9ED);
const _ctaBlack = Color(0xFF1A1A1A);

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
          if (d > 1) const SizedBox(width: 8),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _ctaBlack : _actionGray,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Day $day',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textSecondary,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
