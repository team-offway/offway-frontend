import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 핵심 정책: 모든 코스는 최대 2박3일 → 가는날~오는날 간격 최대 2일
const int kMaxTripSpanDays = 2;

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

  /// 캘린더 날짜 탭 처리.
  /// 시작일 없음 → 시작일 지정 / 시작일만 있음 → 범위 확정(2박3일 이내) 또는 재시작
  void selectDate(DateTime day) {
    final start = state.startDate;
    final end = state.endDate;

    if (start == null || end != null) {
      // 새 선택 시작 (기존 범위가 있으면 리셋)
      state = state._withDates(day, null);
      return;
    }
    final diff = day.difference(start).inDays;
    if (diff < 0 || diff > kMaxTripSpanDays) {
      // 시작일 이전이거나 2박3일 초과 → 해당 날짜로 다시 시작
      state = state._withDates(day, null);
    } else {
      // 범위 확정 (같은 날 = 당일치기)
      state = state._withDates(start, day);
    }
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
