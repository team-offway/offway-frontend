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

/// 코스 추천 위저드(O-04-0 ~ O-08)가 단계별로 채워가는 조건.
/// 이후 스텝(이동수단·일정밀도) 필드를 여기에 추가한다.
class CourseWizardDraft {
  const CourseWizardDraft({
    this.datePath,
    this.startDate,
    this.endDate,
    this.periodStyle,
    this.weekendPattern,
    this.leaveDaysToUse,
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

  bool get hasDateRange => startDate != null && endDate != null;

  /// 기간스타일 스텝 완료 여부 (하위 선택까지 포함)
  bool get isPeriodStyleComplete => switch (periodStyle) {
    PeriodStyle.dayTrip => true,
    PeriodStyle.weekendCombo => weekendPattern != null,
    PeriodStyle.leaveOnly => leaveDaysToUse != null,
    null => false,
  };
}

/// 핵심 정책: 모든 코스는 최대 2박3일 → 가는날~오는날 간격 최대 2일
const int kMaxTripSpanDays = 2;

class CourseWizardNotifier extends Notifier<CourseWizardDraft> {
  @override
  CourseWizardDraft build() => const CourseWizardDraft();

  void selectDatePath(DatePathChoice choice) {
    state = CourseWizardDraft(
      datePath: choice,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: state.periodStyle,
      weekendPattern: state.weekendPattern,
      leaveDaysToUse: state.leaveDaysToUse,
    );
  }

  /// 기간스타일 선택. 스타일이 바뀌면 하위 선택(요일 조합·연차일수)은 초기화.
  void selectPeriodStyle(PeriodStyle style) {
    state = CourseWizardDraft(
      datePath: state.datePath,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: style,
      weekendPattern: style == state.periodStyle ? state.weekendPattern : null,
      leaveDaysToUse: style == state.periodStyle ? state.leaveDaysToUse : null,
    );
  }

  void selectWeekendPattern(WeekendPattern pattern) {
    state = CourseWizardDraft(
      datePath: state.datePath,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: state.periodStyle,
      weekendPattern: pattern,
      leaveDaysToUse: state.leaveDaysToUse,
    );
  }

  void selectLeaveDays(int days) {
    state = CourseWizardDraft(
      datePath: state.datePath,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: state.periodStyle,
      weekendPattern: state.weekendPattern,
      leaveDaysToUse: days,
    );
  }

  /// 캘린더 날짜 탭 처리.
  /// 시작일 없음 → 시작일 지정 / 시작일만 있음 → 범위 확정(2박3일 이내) 또는 재시작
  void selectDate(DateTime day) {
    final start = state.startDate;
    final end = state.endDate;

    CourseWizardDraft withRange(DateTime? newStart, DateTime? newEnd) {
      return CourseWizardDraft(
        datePath: state.datePath,
        startDate: newStart,
        endDate: newEnd,
        periodStyle: state.periodStyle,
        weekendPattern: state.weekendPattern,
        leaveDaysToUse: state.leaveDaysToUse,
      );
    }

    if (start == null || end != null) {
      // 새 선택 시작 (기존 범위가 있으면 리셋)
      state = withRange(day, null);
      return;
    }
    final diff = day.difference(start).inDays;
    if (diff < 0 || diff > kMaxTripSpanDays) {
      // 시작일 이전이거나 2박3일 초과 → 해당 날짜로 다시 시작
      state = withRange(day, null);
    } else {
      // 범위 확정 (같은 날 = 당일치기)
      state = withRange(start, day);
    }
  }

  void reset() => state = const CourseWizardDraft();
}

final courseWizardProvider =
    NotifierProvider<CourseWizardNotifier, CourseWizardDraft>(
      CourseWizardNotifier.new,
    );
