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
  const CourseSaveDateScreen({super.key, required this.travelDays});

  /// 코스 길이 (1=당일치기 · 3=2박3일)
  final int travelDays;

  @override
  ConsumerState<CourseSaveDateScreen> createState() =>
      _CourseSaveDateScreenState();
}

class _CourseSaveDateScreenState extends ConsumerState<CourseSaveDateScreen> {
  DateTime? _start;

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
                // 길이가 정해진 코스라 시작일만 고르면 범위가 완성된다
                onSelect: (day) => setState(() => _start = day),
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
