import 'package:flutter/material.dart' show DateUtils;

/// 서버 API가 쓰는 날짜 표기 (ISO-8601, `2026-08-14`).
///
/// 시각은 버린다 — 서버의 date 필드는 날짜만 받는다.
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 요일 한 글자 (`월` … `일`).
String weekdayLabel(DateTime d) => weekdayLabelOf(d.weekday);

/// 요일 한 글자 — `DateTime.weekday` 값(월=1 … 일=7)으로.
String weekdayLabelOf(int weekday) => _weekdayLabels[weekday - 1];

/// 요일을 띄어 붙인 날짜 (`7.26 월`) — 코스 일차 머리에 쓴다.
String monthDaySpacedWeekday(DateTime d) =>
    '${d.month}.${d.day} ${weekdayLabel(d)}';

/// 0을 채운 연월일에 요일 (`2026.09.05(토)`) — 연차 사용 내역에 쓴다.
String fullDateWithWeekday(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}'
    '.${d.day.toString().padLeft(2, '0')}(${weekdayLabel(d)})';

/// 여행 날짜 범위 (`2026.7.20 - 7.22`).
///
/// [collapseSameDay]가 참이면 하루짜리를 한 번만 쓴다(`2026.7.20`) — 공유
/// 코스·공유 이미지의 표기다. 내 코스 목록·상세는 같은 날도 범위로 쓴다
/// (`2026.7.20 - 7.20`) — 화면마다 지금 보이는 모양 그대로 둔다.
String tripDateRangeLabel(
  DateTime start,
  DateTime? end, {
  bool collapseSameDay = true,
}) => end == null || (collapseSameDay && DateUtils.isSameDay(start, end))
    ? '${start.year}.${start.month}.${start.day}'
    : '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}';

/// 여행 일수 → 기간 라벨 (`당일치기` · `1박2일` · `2박3일`).
///
/// 코스 확정·공유 코스 제목은 붙여 쓰고, 저장 코스 카드에서 나오는 값(공유
/// 이미지·위젯에 실린다)은 띄어 쓴다([spaced]) — 화면마다 지금 보이는 모양
/// 그대로 둔다.
String tripDurationLabel(int days, {bool spaced = false}) => switch (days) {
  <= 1 => '당일치기',
  2 => spaced ? '1박 2일' : '1박2일',
  _ => spaced ? '2박 3일' : '2박3일',
};

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
