import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../application/course_wizard_provider.dart';

/// O-04-0 · 여행 날짜 선택 캘린더 (A 경로, 와이어프레임)
/// 가는날~오는날 범위 선택, 최대 2박3일. X 닫기 시 위저드를 종료하고 홈으로.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _textMuted = Color(0xFF545A66);
  static const _sunday = Color(0xFFE60012);
  static const _bannerBg = Color(0xFFC5C8CE);
  static const _selectedBlue = Color(0xFF3182F6);
  static const _rangeBand = Color(0x1A3182F6);
  static const _disabledDay = Color(0xFFC5C8CE);
  static const _ctaDisabled = Color(0xFFC5C8CE);
  static const _ctaEnabled = Color(0xFF191B1F);

  /// 오늘 기준으로 노출할 월 수
  static const _monthCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseWizardProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: () {
                  // 위저드 이탈: 조건 초기화 후 홈으로
                  ref.read(courseWizardProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
                child: const Icon(Icons.close, size: 26, color: _labelNormal),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(23, 20, 23, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '여행 날짜 선택',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _labelNormal,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '일정에 따른 코스를 추천해드려요.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _textTertiary,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              height: 44,
              color: _bannerBg,
              padding: const EdgeInsets.symmetric(horizontal: 27),
              child: const Row(
                children: [
                  Icon(Icons.error, size: 20, color: _labelNormal),
                  SizedBox(width: 10),
                  Text(
                    '최대 2박3일까지 선택할 수 있어요',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                itemCount: _monthCount,
                itemBuilder: (context, i) {
                  final month = DateTime(today.year, today.month + i);
                  return _MonthCalendar(
                    month: month,
                    today: today,
                    draft: draft,
                    onSelect: (day) =>
                        ref.read(courseWizardProvider.notifier).selectDate(day),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: draft.hasDateRange
                      ? () {
                          // TODO(wizard): 이동수단(O-05) 화면 작업 시 연결
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ctaEnabled,
                    disabledBackgroundColor: _ctaDisabled,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '선택 완료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.draft,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final CourseWizardDraft draft;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstDay.weekday % 7; // 일요일 시작 그리드

    return Column(
      children: [
        Text(
          '${month.year}년 ${month.month}월',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: CalendarScreen._textMuted,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CalendarScreen._textTertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < ((leadingEmpty + daysInMonth + 6) ~/ 7); row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _buildCell(row * 7 + col - leadingEmpty + 1)),
            ],
          ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildCell(int dayNumber) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 52);
    }
    final date = DateTime(month.year, month.month, dayNumber);
    final isPast = date.isBefore(today);
    final isSunday = date.weekday == DateTime.sunday;
    final isStart = draft.startDate == date;
    final isEnd = draft.endDate == date;
    final inRange =
        draft.hasDateRange &&
        date.isAfter(draft.startDate!) &&
        date.isBefore(draft.endDate!);

    Color textColor;
    if (isStart || isEnd) {
      textColor = Colors.white;
    } else if (isPast) {
      textColor = CalendarScreen._disabledDay;
    } else if (isSunday) {
      textColor = CalendarScreen._sunday;
    } else {
      textColor = Colors.black;
    }

    final label = isStart && !isEnd || (isStart && isEnd)
        ? '가는날'
        : isEnd
        ? '오는날'
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isPast ? null : () => onSelect(date),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 범위 배경 밴드
            if (inRange ||
                ((isStart || isEnd) &&
                    draft.startDate != draft.endDate &&
                    draft.hasDateRange))
              Positioned(
                top: 0,
                left: isStart ? null : 0,
                right: isEnd ? null : 0,
                width: isStart || isEnd ? 26 : null,
                child: Container(height: 36, color: CalendarScreen._rangeBand),
              ),
            if (isStart || isEnd)
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: CalendarScreen._selectedBlue,
                  shape: BoxShape.circle,
                ),
              ),
            Positioned(
              top: 7,
              child: Text(
                '$dayNumber',
                style: TextStyle(fontSize: 17, color: textColor),
              ),
            ),
            if (label != null)
              Positioned(
                top: 38,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: CalendarScreen._selectedBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
