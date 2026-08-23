import '../../../core/constants/trip_constants.dart';

/// '주말 포함 여행' 요일 선택 상태 — 고른 요일 범위와 그 규칙.
///
/// 시안 정책:
/// - 시작 요일을 고르면 **그 요일부터 앞으로만** 이어 고른다
/// - 시작 요일부터 최대 [kMaxTripSpanDays]박, 즉 3일까지만
/// - **연속된 요일만** — 목·일처럼 띄어 고를 수 없다
/// - 하루만 고른 상태는 당일치기라 완료할 수 없다(별도 옵션이 이미 있다)
/// - **토·일이 최소 하루는 들어가야 한다** — '주말 포함 여행'이기 때문이다
///
/// 요일은 `DateTime.monday`(1) ~ `DateTime.sunday`(7)를 쓴다.
///
/// **주를 넘어간다.** 일요일 다음은 월요일이다 — 일요일 출발 2박3일(일·월·화)은
/// 현실에 있는 여행이고, 시안이 월~일 한 줄로 보여주는 것은 표시 방식일 뿐
/// 요일의 순환과 무관하다. 그래서 시작 요일과 일수로 담고, 화면에 칠할 때
/// 감싸진 요일까지 [contains]로 판단한다.
class WeekdayRange {
  const WeekdayRange({this.start, this.days = 0});

  /// 아무것도 고르지 않은 상태
  const WeekdayRange.empty() : start = null, days = 0;

  /// 고른 첫 요일 (1=월 … 7=일)
  final int? start;

  /// 고른 날 수 (0~3). 주를 넘어가면 [start]에서 감싸 센다
  final int days;

  /// 최대로 고를 수 있는 일수 — 2박3일이면 3일
  static const maxDays = kMaxTripSpanDays + 1;

  /// 완료할 수 있는 최소 일수. 하루는 당일치기라 이 모달의 몫이 아니다
  static const minDays = 2;

  static const _weekLength = 7;

  bool get isEmpty => start == null;

  /// 숙박 수 — 2일이면 1박
  int get nights => days == 0 ? 0 : days - 1;

  /// 완료 버튼을 누를 수 있는지.
  ///
  /// 하루만 고른 상태(당일치기)와 **주말이 없는 범위**를 막는다. 후자는
  /// 목·금처럼 평일만 이어 고른 경우다 — 그건 '연차만' 옵션의 몫이다.
  bool get canConfirm => days >= minDays && includesWeekend;

  /// 고른 범위에 토·일이 하루라도 있는지
  bool get includesWeekend {
    if (start == null) return false;
    for (var i = 0; i < days; i++) {
      if (_isWeekend(_wrap(start! + i))) return true;
    }
    return false;
  }

  /// 마지막 요일. 주를 넘어가면 감싼 값이다(일요일 시작 3일 → 화요일)
  int? get end => start == null ? null : _wrap(start! + days - 1);

  /// [weekday]가 고른 범위 안에 있는지 — 감싸진 요일도 포함한다
  bool contains(int weekday) {
    if (start == null) return false;
    return _offsetFromStart(weekday) < days;
  }

  /// [weekday]를 지금 고를 수 있는지.
  ///
  /// 아직 아무것도 안 골랐으면 **주말과 한 범위로 묶일 수 있는 요일**만
  /// 열어 둔다. 첫 탭이 곧 시작점이지만 뒤이어 앞쪽으로도 이어붙일 수 있어
  /// (월을 누르고 토·일을 붙이면 토·일·월), 시작점만 놓고 판단하면 월·화가
  /// 억울하게 막힌다. 어느 자리에 놓든 주말에 닿지 못하는 요일은 수뿐이다 —
  /// 수가 든 3일 구간은 월화수·화수목·수목금뿐이라 전부 평일이다.
  ///
  /// 하나라도 골랐으면 **앞뒤로 [maxDays] 안에 들면서, 누른 뒤에도 주말에
  /// 닿을 길이 남는 요일**이 남는다. 뒤로 이어붙일 수 있어야 월·화에서
  /// 시작한 사람이 토·일을 붙일 수 있다.
  ///
  /// 길이 막히는 경우를 함께 걸러낸다 — 월을 고른 뒤 수를 누르면 월·화·수가
  /// 되는데, 주말이 없는 채로 상한을 다 써 완료할 수 없다. 고르고 나서야
  /// 알게 되면 헛걸음이므로 누르기 전에 막는다.
  bool canSelect(int weekday) {
    if (start == null) return _canPairWithWeekend(weekday);
    // 이미 고른 범위 안이면 되돌리기(하루로 재시작)라 늘 열어 둔다
    if (contains(weekday)) return true;

    final forward = _offsetFromStart(weekday);
    if (forward < maxDays) {
      return _leadsToWeekend(start!, forward + 1);
    }
    final total = _backwardReach(weekday);
    return total != null && _leadsToWeekend(weekday, total);
  }

  /// [first]에서 [length]일짜리 범위가 주말을 품거나, 상한이 남아 아직
  /// 주말까지 늘릴 수 있는지
  static bool _leadsToWeekend(int first, int length) {
    for (var i = 0; i < maxDays; i++) {
      // 이미 든 날이거나(i < length), 앞뒤로 더 붙일 수 있는 자리
      if (_isWeekend(_wrap(first + i))) return true;
    }
    // 앞쪽으로 당겨 붙일 수 있는 만큼도 본다
    for (var back = 1; back <= maxDays - length; back++) {
      if (_isWeekend(_wrap(first - back + _weekLength))) return true;
    }
    return false;
  }

  /// [weekday]를 앞에 붙였을 때의 새 일수 — 상한을 넘으면 null.
  ///
  /// 마지막 요일은 그대로 두고 시작만 앞으로 당긴다
  int? _backwardReach(int weekday) {
    final gap = (start! - weekday + _weekLength) % _weekLength;
    if (gap == 0) return null;
    final total = gap + days;
    return total <= maxDays ? total : null;
  }

  /// [weekday]가 들어가는 [maxDays]짜리 연속 구간 중 주말이 든 게 있는지
  static bool _canPairWithWeekend(int weekday) {
    // 구간의 시작을 weekday에서 최대 maxDays-1 앞까지 물려 본다
    for (var back = 0; back < maxDays; back++) {
      final first = _wrap(weekday - back + _weekLength);
      for (var i = 0; i < maxDays; i++) {
        if (_isWeekend(_wrap(first + i))) return true;
      }
    }
    return false;
  }

  static bool _isWeekend(int weekday) =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  /// [weekday]를 탭했을 때의 다음 상태.
  ///
  /// - 아무것도 없으면 그 요일 하루로 시작한다
  /// - 이어지는 요일을 누르면 거기까지 늘어난다(주를 넘어가도 이어진다)
  /// - **앞쪽 요일을 누르면 시작을 그리로 당긴다** — 월을 먼저 고른 사람이
  ///   토·일을 붙일 길이 없으면 월·화에서 완료를 못 하고 갇힌다
  /// - **하루만 고른 상태에서 그 하루를 누르면 해제한다** — 켠 것을 다시
  ///   누르면 꺼지는 것이 칩의 상식이고, 그러지 않으면 비울 길이 없다
  /// - **여러 날 고른 상태에서 범위 안을 누르면 그 요일 하루로 다시 시작한다**
  ///   — 줄이는 방법이 따로 없으면 잘못 고른 사람이 모달을 닫는 수밖에 없다
  /// - 고를 수 없는 요일은 그대로 둔다
  WeekdayRange toggle(int weekday) {
    if (!canSelect(weekday)) return this;
    if (start == null) return WeekdayRange(start: weekday, days: 1);
    if (contains(weekday)) {
      if (days == 1) return const WeekdayRange.empty();
      return WeekdayRange(start: weekday, days: 1);
    }
    // 앞으로 이어지면 늘리고, 아니면 뒤로 당긴다
    if (_offsetFromStart(weekday) < maxDays) {
      return WeekdayRange(start: start, days: _offsetFromStart(weekday) + 1);
    }
    return WeekdayRange(start: weekday, days: _backwardReach(weekday)!);
  }

  /// 시작 요일에서 [weekday]까지 며칠 뒤인지 (0~6). 주를 넘어가면 감싸 센다
  int _offsetFromStart(int weekday) =>
      (weekday - start! + _weekLength) % _weekLength;

  /// 1~7 범위로 되돌린다
  static int _wrap(int weekday) => (weekday - 1) % _weekLength + 1;
}
