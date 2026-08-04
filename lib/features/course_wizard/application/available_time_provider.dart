import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../onboarding/data/leave_repository.dart';
import 'course_wizard_provider.dart';

/// 위저드 조건으로 서버에 가용시간을 물어 여행 기간을 확정한다.
///
/// A 경로(캘린더)는 고른 날짜의 연차 소모·도달 한계를, B 경로(기간스타일)는
/// 기간 자체(다음 쉬는 날 등, 공휴일 반영)까지 서버가 정한다. 후보지역 추천과
/// 코스 생성이 이 결과를 함께 쓴다.
///
/// 계산에 실패하면 null — 호출부가 로컬 추정으로 폴백해 추천 자체는 계속된다.
final availableTimeProvider = FutureProvider.autoDispose<AvailableTime?>((
  ref,
) async {
  final draft = ref.watch(courseWizardProvider);
  final transport = draft.transportMode == TransportMode.publicTransit
      ? 'TRANSIT'
      : 'CAR';

  try {
    if (draft.hasDateRange) {
      return await ref
          .read(leaveRepositoryProvider)
          .availableTime(
            transport: transport,
            startDate: draft.startDate,
            endDate: draft.endDate,
          );
    }
    final style = draft.periodStyle;
    if (style == null) return null;
    return await ref
        .read(leaveRepositoryProvider)
        .availableTime(
          transport: transport,
          baseDate: DateTime.now(),
          periodStyle: switch (style) {
            PeriodStyle.dayTrip => 'DAY_TRIP',
            PeriodStyle.weekendCombo => 'WEEKEND',
            PeriodStyle.leaveOnly => 'CONNECTED',
          },
          weekendBridge: switch (draft.weekendPattern) {
            WeekendPattern.friSatSun => 'FRIDAY',
            WeekendPattern.satSunMon => 'MONDAY',
            null => null,
          },
          leaveDays: style == PeriodStyle.leaveOnly
              ? draft.leaveDaysToUse
              : null,
        );
  } on ApiException {
    return null;
  }
});
