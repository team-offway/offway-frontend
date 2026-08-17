import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/application/course_wizard_provider.dart';
import 'package:offway/features/course_wizard/domain/weekday_range.dart';

/// '주말 포함 여행' 요일 선택 규칙 — 시안 모달 정책 노트를 그대로 고정한다.
void main() {
  const mon = DateTime.monday; // 1
  const tue = DateTime.tuesday; // 2
  const wed = DateTime.wednesday; // 3
  const thu = DateTime.thursday; // 4
  const fri = DateTime.friday; // 5
  const sat = DateTime.saturday; // 6
  const sun = DateTime.sunday; // 7

  /// [start]에서 시작해 [days]일을 고른 상태
  WeekdayRange pick(int start, [int days = 1]) {
    var range = const WeekdayRange.empty().toggle(start);
    if (days > 1) {
      // 마지막 요일을 눌러 한 번에 늘린다 (주를 넘어가면 감싼다)
      range = range.toggle((start + days - 2) % 7 + 1);
    }
    return range;
  }

  group('시작 요일 제한 — 주말에 닿을 수 있어야 고를 수 있다', () {
    test('월·화·수는 처음부터 고를 수 없다', () {
      // 3일을 다 써도 월화수·화수목·수목금 — 토·일에 닿지 못한다.
      // 고르게 두면 완료가 잠긴 이유를 알 수 없다
      const empty = WeekdayRange.empty();
      expect(empty.canSelect(mon), isFalse);
      expect(empty.canSelect(tue), isFalse);
      expect(empty.canSelect(wed), isFalse);
    });

    test('목·금·토·일은 고를 수 있다', () {
      const empty = WeekdayRange.empty();
      for (final d in [thu, fri, sat, sun]) {
        expect(empty.canSelect(d), isTrue, reason: '$d');
      }
    });

    test('고른 게 없으면 완료할 수 없다', () {
      expect(const WeekdayRange.empty().canConfirm, isFalse);
    });
  });

  group('주말이 하루는 들어가야 한다', () {
    test('목·금은 이어졌지만 완료할 수 없다', () {
      // 평일만 이어 고른 것은 '연차만' 옵션의 몫이다
      final range = pick(thu, 2);
      expect(range.days, 2);
      expect(range.includesWeekend, isFalse);
      expect(range.canConfirm, isFalse);
    });

    test('목·금·토는 완료할 수 있다', () {
      final range = pick(thu, 3);
      expect(range.includesWeekend, isTrue);
      expect(range.canConfirm, isTrue);
    });

    test('금·토 · 토·일 · 일·월 모두 주말을 포함한다', () {
      expect(pick(fri, 2).includesWeekend, isTrue, reason: '금·토');
      expect(pick(sat, 2).includesWeekend, isTrue, reason: '토·일');
      expect(pick(sun, 2).includesWeekend, isTrue, reason: '일·월');
    });
  });

  group('주를 넘어간다', () {
    test('일요일에서 시작해 월·화로 이어진다', () {
      // 일요일 다음은 월요일이다 — 일·월·화는 현실에 있는 여행이다
      final sunday = const WeekdayRange.empty().toggle(sun);
      expect(sunday.canSelect(mon), isTrue);
      expect(sunday.canSelect(tue), isTrue);

      final threeDays = sunday.toggle(tue);
      expect(threeDays.days, 3);
      expect(threeDays.end, tue);
      expect(threeDays.contains(mon), isTrue, reason: '사이 월요일도 포함');
      expect(threeDays.canConfirm, isTrue);
    });

    test('토요일에서 시작해 일·월로 이어진다', () {
      final range = pick(sat, 3);
      expect(range.end, mon);
      expect(range.contains(sun), isTrue);
      expect(range.canConfirm, isTrue);
    });

    test('감싼 뒤에도 3일 상한은 지킨다', () {
      // 일 시작 → 일·월·화까지. 수요일은 4일째라 막힌다
      final sunday = const WeekdayRange.empty().toggle(sun);
      expect(sunday.canSelect(wed), isFalse);
    });
  });

  group('범위를 늘리면', () {
    test('2일이면 1박2일이다', () {
      final range = pick(fri, 2);
      expect(range.days, 2);
      expect(range.nights, 1);
    });

    test('3일이면 2박3일이고 그 이상은 막힌다', () {
      final range = pick(fri, 3);
      expect(range.days, 3);
      expect(range.nights, 2);
      // 금 시작이면 금·토·일까지 — 월요일은 4일째다
      expect(range.toggle(mon).days, 3);
    });

    test('사이 요일이 함께 잡힌다 — 연속만 가능하다', () {
      final range = const WeekdayRange.empty().toggle(thu).toggle(sat);
      expect(range.contains(fri), isTrue, reason: '목~토를 고르면 금도 포함');
    });
  });

  group('다시 고르기', () {
    test('하루만 고른 상태에서 그 하루를 누르면 해제된다', () {
      // 켠 것을 다시 누르면 꺼지는 것이 칩의 상식이고,
      // 그러지 않으면 고른 것을 비울 길이 없다
      final one = pick(thu);
      expect(one.days, 1);

      final cleared = one.toggle(thu);
      expect(cleared.isEmpty, isTrue);
      expect(cleared.canConfirm, isFalse);
    });

    test('여러 날 고른 상태에서는 해제가 아니라 하루로 재시작한다', () {
      // 3일에서 한 번에 비우면 실수로 지운 것처럼 보인다
      final range = pick(thu, 3);
      final restarted = range.toggle(sat);
      expect(restarted.isEmpty, isFalse);
      expect(restarted.days, 1);
      expect(restarted.start, sat);
    });

    test('막힌 요일을 눌러도 상태가 바뀌지 않는다', () {
      final range = pick(thu);
      // 목 시작이면 목·금·토까지 — 일요일은 4일째라 막힌다
      expect(range.toggle(sun).days, 1);
    });
  });

  group('서버 계약 매핑', () {
    // 서버는 아직 금·토·일(FRIDAY)과 토·일·월(MONDAY) 두 경우만 받는다
    test('금·토·일은 FRIDAY로 보낸다', () {
      expect(
        const WeekendDays(startWeekday: fri, days: 3).weekendBridge,
        'FRIDAY',
      );
    });

    test('토·일·월은 MONDAY로 보낸다', () {
      expect(
        const WeekendDays(startWeekday: sat, days: 3).weekendBridge,
        'MONDAY',
      );
    });

    test('그 밖의 범위는 보낼 값이 없다 — 로컬 추정으로 떨어진다', () {
      // 서버 계약이 두 조합뿐이라 목·금·토와 일·월·화는 표현할 수 없다
      expect(
        const WeekendDays(startWeekday: thu, days: 3).weekendBridge,
        isNull,
      );
      expect(
        const WeekendDays(startWeekday: sun, days: 3).weekendBridge,
        isNull,
      );
      // 2일짜리도 계약에 없다 (서버는 주말포함을 늘 2박3일로 본다)
      expect(
        const WeekendDays(startWeekday: fri, days: 2).weekendBridge,
        isNull,
      );
    });

    test('마지막 요일을 계산한다', () {
      expect(const WeekendDays(startWeekday: thu, days: 3).endWeekday, sat);
    });
  });
}
