/// 여행 코스 관련 전역 정책 상수.
///
/// 콘텐츠가 얇은 인구감소지역에서 4일 이상 코스는 빈약해지므로
/// 모든 코스는 최대 2박3일로 제한한다 (= 가는날~오는날 간격 최대 2일).
const int kMaxTripSpanDays = 2;

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
  final diff = day.difference(start).inDays;
  if (diff < 0 || diff > kMaxTripSpanDays) {
    // 시작일 이전이거나 상한 초과 → 해당 날짜로 다시 시작
    return (start: day, end: null);
  }
  // 범위 확정 (같은 날 = 당일치기)
  return (start: start, end: day);
}
