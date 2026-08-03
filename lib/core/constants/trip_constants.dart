/// 여행 코스 관련 전역 정책 상수.
///
/// 콘텐츠가 얇은 인구감소지역에서 4일 이상 코스는 빈약해지므로
/// 모든 코스는 최대 2박3일로 제한한다 (= 가는날~오는날 간격 최대 2일).
const int kMaxTripSpanDays = 2;

/// 두 날짜의 달력상 일수 차이.
///
/// `DateTime.difference().inDays`는 경과 시간을 24로 나누므로, 서머타임이 있는
/// 지역에서는 자정끼리도 23·25시간 차가 나 3일 차이가 2일로 계산될 수 있다.
/// 연·월·일만 UTC로 옮겨 비교해 그런 어긋남을 없앤다.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// [from]~[to] 사이에서 연차를 써야 하는 날 수 (양 끝 포함).
///
/// 주말은 원래 쉬는 날이라 연차가 깎이지 않으므로 평일만 센다.
/// 공휴일도 실제로는 빠져야 하지만 달력 데이터가 없어 아직 반영하지 못한다.
/// TODO(server): 공휴일 목록이 생기면 여기서 함께 걸러낸다.
int leaveDaysBetween(DateTime from, DateTime to) {
  var count = 0;
  for (var d = 0; d <= calendarDaysBetween(from, to); d++) {
    final day = DateTime(from.year, from.month, from.day + d);
    if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
      count++;
    }
  }
  return count;
}

/// 캘린더 날짜 탭을 가는날/오는날 범위로 해석한다.
/// 시작일 없음 → 시작일 지정 / 시작일만 있음 → 범위 확정([kMaxTripSpanDays]박 이내) 또는 재시작.
/// 위저드와 저장한 코스 일정 지정이 같은 규칙을 쓰도록 한 곳에 둔다.
({DateTime? start, DateTime? end}) resolveTripDateTap({
  required DateTime day,
  required DateTime? start,
  required DateTime? end,
}) {
  if (start == null || end != null) {
    // 새 선택 시작 (기존 범위가 있으면 리셋)
    return (start: day, end: null);
  }
  final diff = calendarDaysBetween(start, day);
  if (diff < 0 || diff > kMaxTripSpanDays) {
    // 시작일 이전이거나 상한 초과 → 해당 날짜로 다시 시작
    return (start: day, end: null);
  }
  // 범위 확정 (같은 날 = 당일치기)
  return (start: start, end: day);
}
