import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/trip_date_range_picker.dart';
import '../application/course_wizard_provider.dart';

/// O-04-0 · 여행 날짜 선택 캘린더 (A 경로)
/// 가는날~오는날 범위 선택, 최대 2박3일. X 닫기 시 위저드를 종료하고 홈으로.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseWizardProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: GestureDetector(
                onTap: () {
                  // 위저드 이탈: 조건 초기화 후 홈으로
                  ref.read(courseWizardProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.close,
                  size: 24,
                  color: AppColors.labelNormal,
                ),
              ),
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
                    '일정에 따른 코스를 추천해드려요.',
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
                today: today,
                startDate: draft.startDate,
                endDate: draft.endDate,
                onSelect: (day) =>
                    ref.read(courseWizardProvider.notifier).selectDate(day),
              ),
            ),
            _buildActionArea(context, draft),
          ],
        ),
      ),
    );
  }

  /// 하단 액션 영역 — 고른 범위가 연차를 며칠 쓰는지 먼저 알리고 CTA를 둔다
  Widget _buildActionArea(BuildContext context, CourseWizardDraft draft) {
    final start = draft.startDate;
    final end = draft.endDate;
    final leaveDays = start != null && end != null
        ? calendarDaysBetween(start, end) + 1
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // 자리를 늘 차지해 날짜를 고를 때 버튼이 아래위로 움직이지 않게 한다
          SizedBox(
            height: 22,
            child: leaveDays == null
                ? null
                : Text(
                    '차감 연차 일수 $leaveDays일',
                    style: AppTypography.body2NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: draft.hasDateRange
                  ? () => context.push(AppRoutes.wizardTransport)
                  : null,
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
              child: Text('선택 완료', style: AppTypography.body1NormalBold),
            ),
          ),
        ],
      ),
    );
  }
}
