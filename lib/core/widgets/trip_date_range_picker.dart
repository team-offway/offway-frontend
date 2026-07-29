import 'package:flutter/material.dart';

import '../constants/trip_constants.dart';

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _textTertiary = Color(0xFFADB1BB);
const _textMuted = Color(0xFF545A66);
const _sunday = Color(0xFFE60012);
const _selectedBlue = Color(0xFF3182F6);
const _rangeBand = Color(0x1A3182F6);
const _disabledDay = Color(0xFFC5C8CE);

/// 가는날~오는날을 고르는 월별 스크롤 캘린더.
/// 코스 위저드와 저장한 코스 일정 지정 화면이 공유한다.
///
/// 최대 [kMaxTripSpanDays]박까지만 고를 수 있고, 범위를 고르는 중에만
/// 상한을 넘는 날짜를 비활성화한다(완성 후에는 다른 시점으로 재선택 가능).
class TripDateRangePicker extends StatelessWidget {
  const TripDateRangePicker({
    super.key,
    required this.today,
    required this.startDate,
    required this.endDate,
    required this.onSelect,
    this.monthCount = 3,
    this.padding = const EdgeInsets.fromLTRB(22, 28, 22, 24),
  });

  final DateTime today;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onSelect;

  /// 오늘 기준으로 노출할 월 수
  final int monthCount;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: monthCount,
      itemBuilder: (context, i) => _MonthCalendar(
        month: DateTime(today.year, today.month + i),
        today: today,
        startDate: startDate,
        endDate: endDate,
        onSelect: onSelect,
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.startDate,
    required this.endDate,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? startDate;
  final DateTime? endDate;
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
            color: _textMuted,
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
                  style: const TextStyle(fontSize: 12, color: _textTertiary),
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
    // 정책: 가는날 선택 시 상한 초과 날짜는 즉시 비활성화.
    // 단, 범위 완성 후에는 다시 활성화해 다른 시점으로 재선택 가능하게 한다
    final start = startDate;
    final isSelecting = start != null && endDate == null;
    // Duration 더하기 대신 달력 일수로 비교한다 (서머타임 지역에서 어긋남 방지)
    final isBeyondLimit =
        isSelecting && calendarDaysBetween(start, date) > kMaxTripSpanDays;
    final isDisabled = isPast || isBeyondLimit;
    final isSunday = date.weekday == DateTime.sunday;
    final isStart = startDate == date;
    final isEnd = endDate == date;
    final hasRange = startDate != null && endDate != null;
    final inRange =
        hasRange && date.isAfter(startDate!) && date.isBefore(endDate!);

    Color textColor;
    if (isStart || isEnd) {
      textColor = Colors.white;
    } else if (isDisabled) {
      textColor = _disabledDay;
    } else if (isSunday) {
      textColor = _sunday;
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
      onTap: isDisabled ? null : () => onSelect(date),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 범위 배경 밴드
            if (inRange ||
                ((isStart || isEnd) && startDate != endDate && hasRange))
              Positioned(
                top: 0,
                left: isStart ? null : 0,
                right: isEnd ? null : 0,
                width: isStart || isEnd ? 26 : null,
                child: Container(height: 36, color: _rangeBand),
              ),
            if (isStart || isEnd)
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _selectedBlue,
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
                    color: _selectedBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 캘린더 상단의 "최대 2박3일까지 선택할 수 있어요" 안내 배너
class TripDateLimitBanner extends StatelessWidget {
  const TripDateLimitBanner({super.key});

  static const _bannerBg = Color(0xFFC5C8CE);
  static const _labelNormal = Color(0xFF171719);

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
