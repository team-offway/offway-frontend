import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/trip_date_range_picker.dart';
import '../application/course_wizard_provider.dart';

/// O-04-0 · 여행 날짜 선택 캘린더 (A 경로, 와이어프레임)
/// 가는날~오는날 범위 선택, 최대 2박3일. X 닫기 시 위저드를 종료하고 홈으로.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _ctaDisabled = Color(0xFFC5C8CE);
  static const _ctaEnabled = Color(0xFF191B1F);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: draft.hasDateRange
                      ? () => context.push(AppRoutes.wizardTransport)
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
