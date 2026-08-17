import '../../../core/constants/trip_constants.dart';

/// '주말 포함 여행' 요일 선택 상태 — 고른 요일 범위와 그 규칙.
///
/// 시안 정책:
/// - 시작 요일을 고르면 **그 이전 요일은 고를 수 없다**(과거 방향 방지)
/// - 시작 요일부터 최대 [kMaxTripSpanDays]박, 즉 3일까지만
/// - **연속된 요일만** — 목·일처럼 띄어 고를 수 없다
/// - 하루만 고른 상태는 당일치기라 완료할 수 없다(별도 옵션이 이미 있다)
///
/// 요일은 `DateTime.monday`(1) ~ `DateTime.sunday`(7)를 쓴다. 주를 넘기지
/// 않는다 — 시안이 월~일 한 줄만 보여주고, 일요일 다음은 다시 월요일이 아니라
/// 그냥 끝이다.
class WeekdayRange {
  const WeekdayRange({this.start, this.end});

  /// 아무것도 고르지 않은 상태
  const WeekdayRange.empty() : start = null, end = null;

  /// 고른 첫 요일 (1=월 … 7=일)
  final int? start;

  /// 고른 마지막 요일. 하루만 골랐으면 [start]와 같다
  final int? end;

  /// 최대로 고를 수 있는 일수 — 2박3일이면 3일
  static const maxDays = kMaxTripSpanDays + 1;

  /// 완료할 수 있는 최소 일수. 하루는 당일치기라 이 모달의 몫이 아니다
  static const minDays = 2;

  bool get isEmpty => start == null;

  /// 고른 날 수 (0~3)
  int get days => start == null ? 0 : end! - start! + 1;

  /// 숙박 수 — 2일이면 1박
  int get nights => days == 0 ? 0 : days - 1;

  /// 완료 버튼을 누를 수 있는지. 하루만 고른 상태는 막는다
  bool get canConfirm => days >= minDays;

  bool contains(int weekday) =>
      start != null && weekday >= start! && weekday <= end!;

  /// [weekday]를 지금 고를 수 있는지.
  ///
  /// 아직 아무것도 안 골랐으면 전부 고를 수 있다. 하나라도 골랐으면
  /// **이미 고른 범위 + 그 뒤로 이어지는 요일**만 남는다.
  bool canSelect(int weekday) {
    if (start == null) return true;
    if (contains(weekday)) return true;
    // 시작보다 앞이면 과거 방향이라 막는다
    if (weekday < start!) return false;
    // 시작부터 세어 상한을 넘으면 막는다
    return weekday - start! + 1 <= maxDays;
  }

  /// [weekday]를 탭했을 때의 다음 상태.
  ///
  /// - 아무것도 없으면 그 요일 하루로 시작한다
  /// - 이어지는 요일을 누르면 거기까지 늘어난다
  /// - **이미 고른 범위 안을 누르면 그 요일 하루로 다시 시작한다** — 줄이는
  ///   방법이 따로 없으면 잘못 고른 사람이 모달을 닫는 수밖에 없다
  /// - 고를 수 없는 요일은 그대로 둔다
  WeekdayRange toggle(int weekday) {
    if (!canSelect(weekday)) return this;
    if (start == null) return WeekdayRange(start: weekday, end: weekday);
    if (contains(weekday)) {
      return WeekdayRange(start: weekday, end: weekday);
    }
    return WeekdayRange(start: start, end: weekday);
  }
}
