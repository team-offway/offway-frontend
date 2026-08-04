import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/trip_constants.dart';

/// STEP0 갈림길 선택지
enum DatePathChoice {
  /// 가고싶은 날짜가 있어요 → 캘린더 직접 선택(A 경로)
  haveDates,

  /// 아직 안 정했어요 → 기간 스타일 선택(B 경로)
  undecided,
}

/// B 경로 기간 스타일(O-04)
enum PeriodStyle {
  /// 당일치기 · 반차
  dayTrip,

  /// 주말 포함 여행 → 금토일/토일월 중 선택
  weekendCombo,

  /// 연차만 (주말 미포함) → 사용 연차일수 선택
  leaveOnly,
}

/// 주말 포함 여행에서 하루 더 쉴 요일 조합
enum WeekendPattern {
  /// 금·토·일
  friSatSun,

  /// 토·일·월
  satSunMon,
}

/// 이동수단(O-05)
enum TransportMode { publicTransit, car }

/// 일정 밀도(O-06)
enum ScheduleDensity { packed, relaxed }

// 2박3일 정책과 날짜 해석 규칙은 core로 이관 (core가 feature에 의존하지 않도록)

/// 코스 추천 위저드(O-04-0 ~ O-08)가 단계별로 채워가는 조건.
class CourseWizardDraft {
  const CourseWizardDraft({
    this.datePath,
    this.startDate,
    this.endDate,
    this.periodStyle,
    this.weekendPattern,
    this.leaveDaysToUse,
    this.transportMode,
    this.scheduleDensity,
  });

  final DatePathChoice? datePath;

  /// A 경로(캘린더)에서 선택한 가는날/오는날. 당일치기는 두 값이 같다.
  final DateTime? startDate;
  final DateTime? endDate;

  /// B 경로(기간스타일) 선택값
  final PeriodStyle? periodStyle;
  final WeekendPattern? weekendPattern;

  /// 연차만 선택 시 사용할 연차일수 (1~3일)
  final int? leaveDaysToUse;

  final TransportMode? transportMode;
  final ScheduleDensity? scheduleDensity;

  bool get hasDateRange => startDate != null && endDate != null;

  /// 선택 조건 기준 희망 여행일수 (1~3일, 코스 매칭용)
  int get desiredTripDays {
    if (hasDateRange) {
      return endDate!.difference(startDate!).inDays + 1;
    }
    return switch (periodStyle) {
      PeriodStyle.dayTrip => 1,
      PeriodStyle.weekendCombo => 3,
      PeriodStyle.leaveOnly => leaveDaysToUse ?? 1,
      null => 1,
    };
  }

  /// 코스 생성 API에 보낼 여행 시작일.
  ///
  /// A 경로(캘린더)는 고른 가는날 그대로. B 경로(기간스타일)는 구체 날짜가
  /// 없어 스타일에서 가장 가까운 시작일을 추정한다 — 주말포함은 연휴 첫날,
  /// 연차만은 다음 월요일, 당일치기는 다음 토요일(주말 나들이 가정).
  /// 오늘이 그 요일이면 일주일 뒤로 미룬다(당일 출발 코스는 준비가 안 된다).
  ///
  /// TODO(정책): B 경로의 날짜 추정 규칙은 임시다. 팀 확정 후 조정할 것.
  DateTime travelStartDate(DateTime today) {
    if (startDate != null) return startDate!;
    final targetWeekday = switch (periodStyle) {
      PeriodStyle.weekendCombo
          when weekendPattern == WeekendPattern.friSatSun =>
        DateTime.friday,
      PeriodStyle.weekendCombo => DateTime.saturday,
      PeriodStyle.leaveOnly => DateTime.monday,
      _ => DateTime.saturday,
    };
    final delta = (targetWeekday - today.weekday + 7) % 7;
    return DateTime(
      today.year,
      today.month,
      today.day + (delta == 0 ? 7 : delta),
    );
  }

  /// 기간스타일 스텝 완료 여부 (하위 선택까지 포함)
  bool get isPeriodStyleComplete => switch (periodStyle) {
    PeriodStyle.dayTrip => true,
    PeriodStyle.weekendCombo => weekendPattern != null,
    PeriodStyle.leaveOnly => leaveDaysToUse != null,
    null => false,
  };

  /// 날짜 필드(startDate/endDate)는 별도 시맨틱이 있어 _withDates로만 변경한다.
  CourseWizardDraft copyWith({
    DatePathChoice? datePath,
    PeriodStyle? periodStyle,
    WeekendPattern? weekendPattern,
    int? leaveDaysToUse,
    TransportMode? transportMode,
    ScheduleDensity? scheduleDensity,
  }) {
    return CourseWizardDraft(
      datePath: datePath ?? this.datePath,
      startDate: startDate,
      endDate: endDate,
      periodStyle: periodStyle ?? this.periodStyle,
      weekendPattern: weekendPattern ?? this.weekendPattern,
      leaveDaysToUse: leaveDaysToUse ?? this.leaveDaysToUse,
      transportMode: transportMode ?? this.transportMode,
      scheduleDensity: scheduleDensity ?? this.scheduleDensity,
    );
  }

  CourseWizardDraft _withDates(DateTime? start, DateTime? end) {
    return CourseWizardDraft(
      datePath: datePath,
      startDate: start,
      endDate: end,
      periodStyle: periodStyle,
      weekendPattern: weekendPattern,
      leaveDaysToUse: leaveDaysToUse,
      transportMode: transportMode,
      scheduleDensity: scheduleDensity,
    );
  }
}

class CourseWizardNotifier extends Notifier<CourseWizardDraft> {
  @override
  CourseWizardDraft build() => const CourseWizardDraft();

  void selectDatePath(DatePathChoice choice) {
    state = state.copyWith(datePath: choice);
  }

  /// 캘린더 날짜 탭 처리
  void selectDate(DateTime day) {
    final range = resolveTripDateTap(
      day: day,
      start: state.startDate,
      end: state.endDate,
    );
    state = state._withDates(range.start, range.end);
  }

  /// 기간스타일 선택. 스타일이 바뀌면 하위 선택(요일 조합·연차일수)은 초기화.
  void selectPeriodStyle(PeriodStyle style) {
    if (style == state.periodStyle) return;
    state = CourseWizardDraft(
      datePath: state.datePath,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: style,
      transportMode: state.transportMode,
      scheduleDensity: state.scheduleDensity,
    );
  }

  void selectWeekendPattern(WeekendPattern pattern) {
    state = state.copyWith(weekendPattern: pattern);
  }

  void selectLeaveDays(int days) {
    state = state.copyWith(leaveDaysToUse: days);
  }

  void selectTransport(TransportMode mode) {
    state = state.copyWith(transportMode: mode);
  }

  void selectDensity(ScheduleDensity density) {
    state = state.copyWith(scheduleDensity: density);
  }

  void reset() => state = const CourseWizardDraft();
}

final courseWizardProvider =
    NotifierProvider<CourseWizardNotifier, CourseWizardDraft>(
      CourseWizardNotifier.new,
    );
