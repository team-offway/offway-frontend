import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/trip_constants.dart';
import '../theme/tokens/tokens.dart';

/// 고른 날짜 사이를 잇는 옅은 띠 (Primary 12%)
const _rangeBand = Color(0x1F3DC2FF);

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
    this.monthCount = 12,
    this.padding = const EdgeInsets.fromLTRB(22, 28, 22, 24),
  });

  final DateTime today;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onSelect;

  /// 이번 달부터 노출할 월 수 (기본 1년치)
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

  /// 이 달에 고를 수 있는 날이 하루도 없는지.
  /// 가는날을 고른 뒤 상한을 넘어버린 달은 제목까지 흐려 왜 못 고르는지 보이게 한다.
  bool get _isMonthUnavailable {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (var d = 1; d <= daysInMonth; d++) {
      if (!_isDisabled(DateTime(month.year, month.month, d))) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstDay.weekday % 7; // 일요일 시작 그리드
    final monthOff = _isMonthUnavailable;

    return Column(
      children: [
        Text(
          '${month.year}년 ${month.month}월',
          style: AppTypography.headline1Medium.copyWith(
            color: monthOff ? AppColors.labelAssistive : AppColors.labelNormal,
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
                  style: AppTypography.caption2Bold.copyWith(
                    color: AppColors.labelAssistive,
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

  /// 정책: 지난 날짜와, 가는날을 고른 뒤 상한을 넘는 날짜는 고를 수 없다.
  /// 단, 범위가 완성된 뒤에는 다시 열어 다른 시점으로 재선택할 수 있게 한다.
  bool _isDisabled(DateTime date) {
    if (date.isBefore(today)) return true;
    final start = startDate;
    final isSelecting = start != null && endDate == null;
    // Duration 더하기 대신 달력 일수로 비교한다 (서머타임 지역에서 어긋남 방지)
    return isSelecting && calendarDaysBetween(start, date) > kMaxTripSpanDays;
  }

  Widget _buildCell(int dayNumber) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 52);
    }
    final date = DateTime(month.year, month.month, dayNumber);
    final isDisabled = _isDisabled(date);
    final isSunday = date.weekday == DateTime.sunday;
    final isStart = startDate == date;
    final isEnd = endDate == date;
    final hasRange = startDate != null && endDate != null;
    final inRange =
        hasRange && date.isAfter(startDate!) && date.isBefore(endDate!);

    Color textColor;
    if (isStart || isEnd) {
      textColor = AppColors.staticWhite;
    } else if (isDisabled) {
      textColor = AppColors.labelAssistive;
    } else if (isSunday) {
      textColor = AppAccentColors.foregroundRed;
    } else {
      textColor = AppColors.labelNormal;
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
                  color: AppColors.primaryNormal,
                  shape: BoxShape.circle,
                ),
              ),
            Positioned(
              top: 8,
              child: Text(
                '$dayNumber',
                style: AppTypography.body2NormalMedium.copyWith(
                  color: textColor,
                ),
              ),
            ),
            if (label != null)
              Positioned(
                top: 38,
                left: 0,
                right: 0,
                // 셀 폭에 가둔다 — 글자 배율이 커져도 옆 날짜와 겹치지 않는다
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTypography.caption2Bold.copyWith(
                    color: AppColors.primaryNormal,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      color: AppColors.backgroundNormalAlternative,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 아이콘 원본이 이미 label/alternative와 같은 색이라 그대로 쓴다
          SvgPicture.asset(
            'assets/icons/ic_circle_info.svg',
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 10),
          Text(
            '최대 $kMaxTripSpanDays박${kMaxTripSpanDays + 1}일까지 선택할 수 있어요',
            style: AppTypography.label2Medium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }
}
