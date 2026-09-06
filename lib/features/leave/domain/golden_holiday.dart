/// 연차를 조금 써서 길게 쉴 수 있는 구간 하나 — '연차 쓰기 좋은 날'.
///
/// **앱에 박아 둔 편집 콘텐츠다.** 서버 공휴일 API는 날짜만 주고 이름
/// (개천절·한글날)을 안 주며, 어느 구간을 앞세울지는 사람이 고른 것이라
/// 계산으로 되살릴 수 없다. 해가 바뀌면 [kGoldenHolidays]를 갈아 끼운다.
class GoldenHoliday {
  const GoldenHoliday({
    required this.start,
    required this.end,
    required this.label,
    required this.leaveDays,
  });

  /// 쉬는 첫날·마지막날 (둘 다 포함)
  final DateTime start;
  final DateTime end;

  /// 무슨 연휴인지 — '개천절·한글날'
  final String label;

  /// 이 구간을 통으로 쉬려면 써야 하는 연차 일수
  final int leaveDays;

  /// 구간 전체 일수 — 주말·공휴일·연차를 다 더한 값
  int get totalDays => end.difference(start).inDays + 1;

  /// `10.2(토) – 10.11(월)` — 목록 행의 표기. 시안이 앞뒤 띄운 엔 대시다
  String get rangeLabel => '${_md(start)} – ${_md(end)}';

  /// `10.2(토)-10.11(월)` — 상단 카드의 표기. 큰 글자라 붙여 쓴다
  String get heroRangeLabel => '${_md(start)}-${_md(end)}';

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String _md(DateTime d) =>
      '${d.month}.${d.day}(${_weekdays[d.weekday - 1]})';
}

/// 이 콘텐츠가 다루는 해 — 카드 제목('2027 황금연휴 알아보기')에 쓴다
const kGoldenHolidayYear = 2027;

/// 2027년 연차 쓰기 좋은 날 — 시안 순서 그대로(첫 항목이 상단 카드에 간다).
///
/// 서버 공휴일(`/holidays?year=2027`)과 대조해 둔 값이다: 설날 2.6~2.9,
/// 노동절 5.1(대체 5.3)·어린이날 5.5, 추석 9.14~9.16, 개천절 10.3(대체 10.4)·
/// 한글날 10.9(대체 10.11).
final kGoldenHolidays = [
  GoldenHoliday(
    start: DateTime(2027, 10, 2),
    end: DateTime(2027, 10, 11),
    label: '개천절·한글날',
    leaveDays: 4,
  ),
  GoldenHoliday(
    start: DateTime(2027, 9, 11),
    end: DateTime(2027, 9, 19),
    label: '추석 연휴',
    leaveDays: 2,
  ),
  // 시안은 '연차 4일 · 총 10일'로 적혀 있지만 달력은 9일이고, 그 안의 평일은
  // 5.4·5.6·5.7 셋이다(5.3은 서버 공휴일 목록의 노동절 대체휴일). 화면에
  // 틀린 숫자를 내지 않으려고 달력값을 쓴다 — 시안 쪽에 알려 둘 것
  GoldenHoliday(
    start: DateTime(2027, 5, 1),
    end: DateTime(2027, 5, 9),
    label: '노동절·어린이날',
    leaveDays: 3,
  ),
  GoldenHoliday(
    start: DateTime(2027, 2, 5),
    end: DateTime(2027, 2, 9),
    label: '설날 연휴',
    leaveDays: 1,
  ),
];
