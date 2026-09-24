import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/date_format.dart';

/// 날짜·요일·기간 표기 — 화면마다 따로 만들던 것을 한 곳에 모았다(#367).
void main() {
  final sat = DateTime(2026, 9, 5);

  test('요일', () {
    expect(weekdayLabel(sat), '토');
    expect(weekdayLabelOf(DateTime.monday), '월');
    expect(weekdayLabelOf(DateTime.sunday), '일');
  });

  test('코스 일차 머리 — 띄어 쓴 요일', () {
    expect(monthDaySpacedWeekday(DateTime(2026, 7, 26)), '7.26 일');
  });

  test('연차 사용 내역 — 0을 채운 연월일', () {
    expect(fullDateWithWeekday(sat), '2026.09.05(토)');
  });

  test('여행 날짜 범위 — 하루짜리는 한 번만', () {
    expect(
      tripDateRangeLabel(DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
      '2026.7.20 - 7.22',
    );
    expect(
      tripDateRangeLabel(DateTime(2026, 7, 20), DateTime(2026, 7, 20)),
      '2026.7.20',
    );
    expect(tripDateRangeLabel(DateTime(2026, 7, 20), null), '2026.7.20');
  });

  test('기간 라벨은 붙여 쓴다', () {
    expect(tripDurationLabel(1), '당일치기');
    expect(tripDurationLabel(2), '1박2일');
    expect(tripDurationLabel(3), '2박3일');
  });
}
