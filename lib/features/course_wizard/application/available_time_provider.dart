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

    // 주말 포함은 사용자가 요일 범위를 직접 골랐다 — 그 요일을 날짜로 바꿔
    // 날짜 모드로 보낸다. 기간스타일 모드의 weekendBridge는 금·토·일과
    // 토·일·월 두 조합만 표현할 수 있어 목·금·토나 일·월·화를 담지 못한다
    final weekend = draft.weekendPattern;
    if (style == PeriodStyle.weekendCombo && weekend != null) {
      final today = DateTime.now();
      return await ref
          .read(leaveRepositoryProvider)
          .availableTime(
            transport: transport,
            startDate: weekend.firstStartDate(today),
            endDate: weekend.lastDate(today),
          );
    }

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
          leaveDays: style == PeriodStyle.leaveOnly
              ? draft.leaveDaysToUse
              : null,
        );
  } on ApiException {
    return null;
  }
});
