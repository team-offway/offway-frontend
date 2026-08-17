import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/application/course_wizard_provider.dart';
import 'package:offway/features/course_wizard/domain/weekday_range.dart';

/// '주말 포함 여행' 요일 선택 규칙 — 시안 모달 정책 노트를 그대로 고정한다.
void main() {
  const mon = DateTime.monday; // 1
  const wed = DateTime.wednesday; // 3
  const thu = DateTime.thursday; // 4
  const fri = DateTime.friday; // 5
  const sat = DateTime.saturday; // 6
  const sun = DateTime.sunday; // 7

  group('처음 상태', () {
    test('아무 요일이나 고를 수 있다', () {
      const range = WeekdayRange.empty();
      for (var d = mon; d <= sun; d++) {
        expect(range.canSelect(d), isTrue, reason: '$d');
      }
    });

    test('고른 게 없으면 완료할 수 없다', () {
      expect(const WeekdayRange.empty().canConfirm, isFalse);
    });
  });

  group('시작 요일을 고르면', () {
    final started = const WeekdayRange.empty().toggle(thu);

    test('그 요일 하루가 잡힌다', () {
      expect(started.days, 1);
      expect(started.start, thu);
      expect(started.end, thu);
    });

    test('이전 요일은 고를 수 없다 — 과거 방향 방지', () {
      expect(started.canSelect(wed), isFalse);
      expect(started.canSelect(mon), isFalse);
    });

    test('3일 범위를 넘는 요일은 고를 수 없다', () {
      // 목 기준 목·금·토까지 3일. 일요일은 4일째라 막힌다
      expect(started.canSelect(fri), isTrue);
      expect(started.canSelect(sat), isTrue);
      expect(started.canSelect(sun), isFalse);
    });

    test('하루만 고른 상태는 완료할 수 없다 — 당일치기는 별도 옵션이다', () {
      expect(started.days, 1);
      expect(started.canConfirm, isFalse);
    });
  });

  group('범위를 늘리면', () {
    test('2일이면 1박2일이고 완료할 수 있다', () {
      final range = const WeekdayRange.empty().toggle(thu).toggle(fri);
      expect(range.days, 2);
      expect(range.nights, 1);
      expect(range.canConfirm, isTrue);
    });

    test('3일이면 2박3일이고 그 이상은 막힌다', () {
      final range = const WeekdayRange.empty().toggle(thu).toggle(sat);
      expect(range.days, 3);
      expect(range.nights, 2);
      expect(range.canConfirm, isTrue);
      // 일요일을 눌러도 그대로다
      expect(range.toggle(sun).end, sat);
    });

    test('사이 요일이 함께 잡힌다 — 연속만 가능하다', () {
      final range = const WeekdayRange.empty().toggle(thu).toggle(sat);
      expect(range.contains(fri), isTrue, reason: '목~토를 고르면 금도 포함');
    });
  });

  group('다시 고르기', () {
    test('고른 범위 안을 누르면 그 요일 하루로 다시 시작한다', () {
      // 줄이는 방법이 없으면 잘못 고른 사람이 모달을 닫는 수밖에 없다
      final range = const WeekdayRange.empty().toggle(thu).toggle(sat);
      final restarted = range.toggle(fri);
      expect(restarted.start, fri);
      expect(restarted.end, fri);
      expect(restarted.days, 1);
    });

    test('막힌 요일을 눌러도 상태가 바뀌지 않는다', () {
      final range = const WeekdayRange.empty().toggle(thu);
      expect(range.toggle(mon).start, thu, reason: '과거 방향');
      expect(range.toggle(sun).end, thu, reason: '3일 초과');
    });
  });

  group('주를 넘기지 않는다', () {
    test('일요일에서 시작하면 하루만 고를 수 있다', () {
      // 시안이 월~일 한 줄만 보여준다 — 일요일 다음은 다시 월요일이 아니다
      final range = const WeekdayRange.empty().toggle(sun);
      expect(range.days, 1);
      expect(range.canConfirm, isFalse);
      expect(range.canSelect(mon), isFalse);
    });

    test('토요일에서 시작하면 토·일 2일까지다', () {
      final range = const WeekdayRange.empty().toggle(sat);
      expect(range.canSelect(sun), isTrue);
      expect(range.toggle(sun).days, 2);
    });
  });

  group('서버 계약 매핑', () {
    // 서버는 아직 금·토·일(FRIDAY)과 토·일·월(MONDAY) 두 경우만 받는다
    test('금·토·일은 FRIDAY로 보낸다', () {
      const days = WeekendDays(startWeekday: fri, days: 3);
      expect(days.weekendBridge, 'FRIDAY');
    });

    test('토·일·월은 MONDAY로 보낸다', () {
      const days = WeekendDays(startWeekday: sat, days: 3);
      expect(days.weekendBridge, 'MONDAY');
    });

    test('그 밖의 범위는 보낼 값이 없다 — 로컬 추정으로 떨어진다', () {
      // 서버 계약이 두 조합뿐이라 목·금·토는 표현할 수 없다
      expect(
        const WeekendDays(startWeekday: thu, days: 3).weekendBridge,
        isNull,
      );
      // 2일짜리도 계약에 없다 (서버는 주말포함을 늘 2박3일로 본다)
      expect(
        const WeekendDays(startWeekday: fri, days: 2).weekendBridge,
        isNull,
      );
    });

    test('마지막 요일을 계산한다', () {
      const days = WeekendDays(startWeekday: thu, days: 3);
      expect(days.endWeekday, sat);
    });
  });
}
