import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/trip_date_range_picker.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../course_wizard/presentation/calendar_screen.dart'
    show tripConsumedLeaveProvider;

/// 담기 직전 여행 날짜 지정 (프리셋 경로 전용).
///
/// 당일치기·주말포함·연차만으로 만든 코스는 날짜가 없는 채로 오는데, 날짜 없이
/// 저장하면 날씨·휴무일 안내도 연차 차감도 못 한다. 그래서 담기 시점에 여기서
/// 날짜를 확정한다. 캘린더에서 미리 날짜를 고른 코스는 이 화면을 거치지 않는다.
///
/// 코스 길이는 이미 정해져 있으므로 시작일만 고르면 범위가 그 길이로 완성된다.
/// 선택 완료 시 시작일을 결과로 돌려준다 (`context.pop<DateTime>`).
class CourseSaveDateScreen extends ConsumerStatefulWidget {
  const CourseSaveDateScreen({
    super.key,
    required this.travelDays,
    this.startWeekday,
  });

  /// 코스 길이 (1=당일치기 · 3=2박3일)
  final int travelDays;

  /// 위저드에서 정한 시작 요일 (`DateTime.monday`~`sunday`). null이면 아무 날.
  ///
  /// '목금토'로 만든 코스는 목요일에 시작해야 그 일정이 성립한다. 그래서
  /// 캘린더도 **목·금·토만** 열어 두고, 셋 중 무엇을 눌러도 그 주 목요일로
  /// 잡는다 — 금요일을 눌렀다고 금토일이 되면 코스와 어긋난다.
  final int? startWeekday;

  @override
  ConsumerState<CourseSaveDateScreen> createState() =>
      _CourseSaveDateScreenState();
}

class _CourseSaveDateScreenState extends ConsumerState<CourseSaveDateScreen> {
  DateTime? _start;

  /// 열어 둘 요일 — 시작 요일부터 코스 길이만큼.
  ///
  /// 시작일만 열면 '목금토' 코스에서 목요일 한 칸만 파랗고 금·토가 회색이라,
  /// 정작 고른 조건이 화면에서 안 읽힌다. 셋 다 열어 두고 누른 날을 시작
  /// 요일로 되돌린다.
  Set<int>? get _allowedWeekdays {
    final start = widget.startWeekday;
    if (start == null) return null;
    return {
      for (var i = 0; i < widget.travelDays; i++)
        // 일요일(7)을 넘으면 다시 월요일(1)로 돈다
        ((start - 1 + i) % 7) + 1,
    };
  }

  /// 누른 날이 속한 구간의 **시작일**.
  ///
  /// 금요일을 눌러도 그 주 목요일이 된다 — 코스는 목금토로 짜였으니 시작이
  /// 목요일이라야 한다. 요일 제한이 없으면 누른 날이 그대로 시작일이다.
  DateTime _alignToStart(DateTime picked) {
    final start = widget.startWeekday;
    if (start == null) return picked;
    final back = (picked.weekday - start + 7) % 7;
    return DateTime(picked.year, picked.month, picked.day - back);
  }

  DateTime? get _end => _start == null
      ? null
      : DateTime(
          _start!.year,
          _start!.month,
          _start!.day + widget.travelDays - 1,
        );

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end;
    // 서버가 평일−공휴일로 계산한 차감 연차 (실패 시 provider가 로컬 근사로 폴백)
    final consumed = start != null && end != null
        ? ref.watch(tripConsumedLeaveProvider((start: start, end: end))).value
        : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
              padding: const EdgeInsets.fromLTRB(6, 0, 20, 0),
              child: AppBackButton(onTap: () => context.pop()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '여행 날짜 선택',
                    style: AppTypography.title3Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '일정에 따른 날씨예보, 휴무일 정보를 알려드려요.',
                    style: AppTypography.body1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const TripDateLimitBanner(),
            Expanded(
              child: TripDateRangePicker(
                today: DateUtils.dateOnly(DateTime.now()),
                startDate: start,
                endDate: end,
                // 위저드에서 요일까지 정한 코스는 그 요일만 열어 둔다
                allowedWeekdays: _allowedWeekdays,
                // 길이가 정해진 코스라 시작일만 고르면 범위가 완성된다.
                // 목금토 중 금요일을 눌러도 시작은 목요일로 되돌린다
                onSelect: (day) => setState(() => _start = _alignToStart(day)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  // 자리를 늘 차지해 날짜를 고를 때 버튼이 움직이지 않게 한다
                  SizedBox(
                    height: 22,
                    child: consumed == null
                        ? null
                        : Text(
                            '차감 연차 일수 ${formatLeaveDays(consumed)}일',
                            style: AppTypography.body2NormalMedium.copyWith(
                              color: AppColors.labelAlternative,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: start == null
                          ? null
                          : () => context.pop<DateTime>(start),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryNormal,
                        disabledBackgroundColor: AppColors.interactionDisable,
                        foregroundColor: AppColors.staticWhite,
                        disabledForegroundColor: AppColors.labelAssistive,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '선택 완료',
                        style: AppTypography.body1NormalBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
