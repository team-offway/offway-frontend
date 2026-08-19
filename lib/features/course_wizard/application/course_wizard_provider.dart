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
  /// 당일치기 · 연차 — 하루 연차를 내고 다녀온다.
  ///
  /// 예전 문구는 '당일치기 · 반차'였다. 앱이 연차 유형을 묻지 않아 서버에
  /// 보낼 값이 없고, 서버는 첫날을 종일(08시 출발·1일 차감)로 본다 —
  /// 반차로 읽으면 1일 깎이는 것이 약속과 어긋난다(#112).
  dayTrip,

  /// 주말 포함 여행 → 금토일/토일월 중 선택
  weekendCombo,

  /// 연차만 (주말 미포함) → 사용 연차일수 선택
  leaveOnly,
}

/// 주말 포함 여행에서 고른 요일 범위.
///
/// 예전에는 금·토·일 / 토·일·월 두 조합만 골랐다. 시안이 월~일에서 이어지는
/// 범위를 직접 고르게 바뀌어, 시작 요일과 일수로 담는다.
class WeekendDays {
  const WeekendDays({required this.startWeekday, required this.days});

  /// 여행 시작 요일 (`DateTime.monday`~`DateTime.sunday`)
  final int startWeekday;

  /// 고른 날 수 (2~3)
  final int days;

  /// 마지막 요일
  int get endWeekday => startWeekday + days - 1;

  /// [today] 이후 가장 가까운 [startWeekday]의 날짜.
  ///
  /// 오늘이 그 요일이어도 **다음 주**로 잡는다 — 오늘 떠나라는 추천은 짐 쌀
  /// 시간이 없다.
  DateTime firstStartDate(DateTime today) {
    final delta = (startWeekday - today.weekday + 7) % 7;
    return DateTime(
      today.year,
      today.month,
      today.day + (delta == 0 ? 7 : delta),
    );
  }

  /// 그 구간의 마지막 날
  DateTime lastDate(DateTime today) {
    final start = firstStartDate(today);
    return DateTime(start.year, start.month, start.day + days - 1);
  }
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
  final WeekendDays? weekendPattern;

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
      PeriodStyle.weekendCombo => weekendPattern?.days ?? 3,
      PeriodStyle.leaveOnly => leaveDaysToUse ?? 1,
      null => 1,
    };
  }

  /// 여행 시작일의 로컬 추정 — **가용시간 계산(서버)이 실패했을 때의 폴백**.
  ///
  /// 평소에는 서버(available-time)가 공휴일까지 반영해 날짜를 확정한다.
  /// 여기는 그 호출이 안 될 때 추천이 멈추지 않게 하는 근사다:
  /// A 경로(캘린더)는 고른 가는날 그대로, B 경로는 주말포함 → 연휴 첫날,
  /// 연차만 → 다음 월요일, 당일치기 → 다음 토요일로 어림한다.
  DateTime travelStartDate(DateTime today) {
    if (startDate != null) return startDate!;
    final targetWeekday = switch (periodStyle) {
      // 사용자가 고른 시작 요일을 그대로 쓴다 — 조합 두 개가 아니라 범위다
      PeriodStyle.weekendCombo =>
        weekendPattern?.startWeekday ?? DateTime.saturday,
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
    WeekendDays? weekendPattern,
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

  void selectWeekendDays(WeekendDays days) {
    state = state.copyWith(weekendPattern: days);
  }

  void selectLeaveDays(int days) {
    state = state.copyWith(leaveDaysToUse: days);
  }

  /// 후보 0곳에서 '다시 설정하기' — 기간·날짜는 그대로 두고
  /// 이동수단부터 다시 고르도록 이후 단계 선택만 비운다
  void restartFromTransport() {
    state = CourseWizardDraft(
      datePath: state.datePath,
      startDate: state.startDate,
      endDate: state.endDate,
      periodStyle: state.periodStyle,
      weekendPattern: state.weekendPattern,
      leaveDaysToUse: state.leaveDaysToUse,
    );
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
