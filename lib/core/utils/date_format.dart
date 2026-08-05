/// 서버 API가 쓰는 날짜 표기 (ISO-8601, `2026-08-14`).
///
/// 시각은 버린다 — 서버의 date 필드는 날짜만 받는다.
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
