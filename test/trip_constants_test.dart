import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/constants/trip_constants.dart';

void main() {
  group('calendarDaysBetween', () {
    test('같은 날은 0, 하루 뒤는 1', () {
      final a = DateTime(2026, 7, 20);
      expect(calendarDaysBetween(a, a), 0);
      expect(calendarDaysBetween(a, DateTime(2026, 7, 21)), 1);
    });

    test('시작일보다 이전이면 음수', () {
      expect(
        calendarDaysBetween(DateTime(2026, 7, 20), DateTime(2026, 7, 19)),
        -1,
      );
    });

    test('월·연 경계를 넘어도 달력 기준으로 센다', () {
      expect(
        calendarDaysBetween(DateTime(2026, 7, 31), DateTime(2026, 8, 2)),
        2,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        1,
      );
    });

    test('두 날짜의 시각이 달라도 달력 기준으로만 센다', () {
      // 서머타임 지역에서는 자정끼리도 23·25시간 차가 나 경과 시간을 24로 나누면
      // 3일 차이가 2일로 계산될 수 있다. 시:분이 섞인 입력으로 그 상황을 재현한다.
      final start = DateTime(2026, 7, 20, 0);
      final end = start.add(const Duration(hours: 71)); // 7/22 23:00
      expect(end.difference(start).inDays, 2); // 시간 기준: 2
      expect(calendarDaysBetween(start, end), 2); // 7/20 → 7/22 이므로 달력도 2

      // 반대로 1시간만 지나도 날짜가 바뀌면 달력 기준은 1일이다
      final lateNight = DateTime(2026, 7, 20, 23);
      final nextMidnight = DateTime(2026, 7, 21, 0);
      expect(nextMidnight.difference(lateNight).inDays, 0); // 시간 기준: 0
      expect(calendarDaysBetween(lateNight, nextMidnight), 1); // 달력 기준: 1
    });
  });

  group('resolveTripDateTap', () {
    final day1 = DateTime(2026, 7, 20);

    test('시작일이 없으면 그 날짜를 가는날로 잡는다', () {
      final r = resolveTripDateTap(day: day1, start: null, end: null);
      expect(r.start, day1);
      expect(r.end, isNull);
    });

    test('범위가 이미 있으면 새로 시작한다', () {
      final r = resolveTripDateTap(
        day: DateTime(2026, 8, 1),
        start: day1,
        end: DateTime(2026, 7, 22),
      );
      expect(r.start, DateTime(2026, 8, 1));
      expect(r.end, isNull);
    });

    test('같은 날을 다시 누르면 당일치기로 확정된다', () {
      final r = resolveTripDateTap(day: day1, start: day1, end: null);
      expect(r.start, day1);
      expect(r.end, day1);
    });

    test('2박3일(2일 차이)까지는 범위로 확정된다', () {
      final end = DateTime(2026, 7, 22);
      final r = resolveTripDateTap(day: end, start: day1, end: null);
      expect(r.start, day1);
      expect(r.end, end);
    });

    test('3박4일(3일 차이)은 초과라 그 날짜로 다시 시작한다', () {
      final tooFar = DateTime(2026, 7, 23);
      final r = resolveTripDateTap(day: tooFar, start: day1, end: null);
      expect(r.start, tooFar);
      expect(r.end, isNull);
    });

    test('시작일 이전을 누르면 그 날짜로 다시 시작한다', () {
      final earlier = DateTime(2026, 7, 19);
      final r = resolveTripDateTap(day: earlier, start: day1, end: null);
      expect(r.start, earlier);
      expect(r.end, isNull);
    });
  });
}
