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

/// 서버 시각 문자열 → [DateTime]. **오프셋이 없으면 KST(+09:00)로 읽는다.**
///
/// 서버는 `2026-09-01T14:03:22`처럼 오프셋 없는 KST를 준다(알림 createdAt,
/// 연차 내역 createdAt). `DateTime.parse`는 오프셋이 없으면 **기기 현지
/// 시간대**로 읽으므로, 한국 밖 기기에서는 경과 시간이 시차만큼 어긋난다 —
/// '3시간 전'이 '12시간 전'으로, 24시간짜리 New 칩이 15시간 만에 꺼진다.
///
/// 오프셋이 이미 붙어 있으면 그대로 둔다. 못 읽으면 null이다.
DateTime? parseServerDateTime(String? raw) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  // 날짜만 온 값(`2026-05-08`)은 시각이 없으면 오프셋을 못 붙인다 —
  // 자정을 명시한다. 그 `-`를 오프셋으로 오인하지 않게 'T' 뒤만 본다
  if (!s.contains('T')) return DateTime.tryParse('${s}T00:00:00+09:00');
  final hasOffset =
      s.endsWith('Z') || RegExp(r'T.*[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.tryParse(hasOffset ? s : '$s+09:00');
}
