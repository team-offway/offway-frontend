/// 서버 API가 쓰는 날짜 표기 (ISO-8601, `2026-08-14`).
///
/// 시각은 버린다 — 서버의 date 필드는 날짜만 받는다.
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 요일 한 글자 (`월` … `일`).
String weekdayLabel(DateTime d) => _weekdayLabels[d.weekday - 1];

/// 요일을 괄호에 넣은 날짜 (`7.20(월)`).
///
/// 월·일에 0을 채우지 않는다 — 시안이 `7.20`이지 `07.20`이 아니다.
String monthDayWithWeekday(DateTime d) =>
    '${d.month}.${d.day}(${weekdayLabel(d)})';

/// 두 날짜를 잇는 여행 기간 (`7.20(월) – 7.22(수) · 2박 3일`).
///
/// 당일치기는 `–` 뒤가 같은 날이라 한 번만 쓰고 '당일치기'로 끝낸다.
/// 이음표는 하이픈(-)이 아니라 시안의 en dash(–)다.
String tripPeriodLabel(DateTime start, DateTime end) {
  final nights = end.difference(start).inDays;
  if (nights <= 0) return '${monthDayWithWeekday(start)} · 당일치기';
  return '${monthDayWithWeekday(start)} – ${monthDayWithWeekday(end)}'
      ' · $nights박 ${nights + 1}일';
}
