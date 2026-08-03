import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
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
              // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
              padding: const EdgeInsets.fromLTRB(10, 0, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  icon: Icons.close,
                  onTap: () {
                    // 위저드 이탈: 조건 초기화 후 홈으로
                    ref.read(courseWizardProvider.notifier).reset();
                    context.go(AppRoutes.home);
                  },
                  semanticLabel: '닫기',
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
    // 주말은 연차가 깎이지 않으므로 평일만 센다
    final leaveDays = start != null && end != null
        ? leaveDaysBetween(start, end)
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
