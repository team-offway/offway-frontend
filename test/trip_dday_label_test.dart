import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';

/// D-day 글자 — 지난 여행인지는 **종료일**로 가른다.
///
/// 공유 코스 화면이 출발일로 갈라 2박3일의 둘째 날에 '여행완료'를 띄웠다(#362).
void main() {
  final start = DateTime(2026, 10, 1);
  final end = DateTime(2026, 10, 3);

  test('출발 전이면 D-n', () {
    expect(tripDDayLabel(start, end, today: DateTime(2026, 9, 28)), 'D-3');
  });

  test('출발일은 D-DAY', () {
    expect(tripDDayLabel(start, end, today: start), 'D-DAY');
  });

  test('여행 둘째·셋째 날도 D-DAY — 끝난 여행이 아니다', () {
    expect(tripDDayLabel(start, end, today: DateTime(2026, 10, 2)), 'D-DAY');
    expect(tripDDayLabel(start, end, today: end), 'D-DAY');
  });

  test('종료일 다음 날부터 null', () {
    expect(tripDDayLabel(start, end, today: DateTime(2026, 10, 4)), isNull);
  });

  test('당일치기', () {
    final day = DateTime(2026, 10, 1);
    expect(tripDDayLabel(day, day, today: day), 'D-DAY');
    expect(tripDDayLabel(day, day, today: DateTime(2026, 10, 2)), isNull);
  });
}
