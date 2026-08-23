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

  group('시작 요일 제한 — 주말과 한 범위로 묶일 수 있어야 고를 수 있다', () {
    test('수는 처음부터 고를 수 없다', () {
      // 수가 든 3일 구간은 월화수·화수목·수목금뿐이라 전부 평일이다.
      // 고르게 두면 완료가 잠긴 이유를 알 수 없다
      expect(const WeekdayRange.empty().canSelect(wed), isFalse);
    });

    test('수를 뺀 여섯 요일은 고를 수 있다', () {
      // 월·화도 앞에 주말을 붙일 수 있다 — 토·일·월, 일·월·화
      const empty = WeekdayRange.empty();
      for (final d in [mon, tue, thu, fri, sat, sun]) {
        expect(empty.canSelect(d), isTrue, reason: '$d');
      }
    });

    test('월을 고른 뒤 수는 막힌다 — 월·화·수는 완료할 수 없다', () {
      // 주말 없이 상한(3일)을 다 써 버려 더 늘릴 수도, 완료할 수도 없다.
      // 고르고 나서야 알게 되면 헛걸음이라 누르기 전에 막는다
      final monday = const WeekdayRange.empty().toggle(mon);
      expect(monday.canSelect(wed), isFalse);
    });

    test('월을 고른 뒤 화·일로 이어 일·월·화를 만들 수 있다', () {
      // 앞 케이스를 막는다고 이쪽까지 닫히면 월에서 시작할 길이 없어진다
      final range = const WeekdayRange.empty().toggle(mon).toggle(tue);
      expect(range.canSelect(sun), isTrue);
      final done = range.toggle(sun);
      expect(done.days, 3);
      expect(done.start, sun); // 일·월·화
      expect(done.canConfirm, isTrue);
    });

    test('어떤 선택도 막다른 길로 가지 않는다', () {
      // 완료도 못 하고 더 넓히지도 못하는 상태가 하나라도 있으면 안 된다
      for (var first = mon; first <= sun; first++) {
        const empty = WeekdayRange.empty();
        if (!empty.canSelect(first)) continue;
        final one = empty.toggle(first);
        for (var next = mon; next <= sun; next++) {
          if (!one.canSelect(next)) continue;
          final two = one.toggle(next);
          if (two.days < WeekdayRange.minDays) continue;
          final canGrow = [
            for (var d = mon; d <= sun; d++)
              if (!two.contains(d) && two.canSelect(d)) d,
          ].isNotEmpty;
          expect(
            two.canConfirm || canGrow,
            isTrue,
            reason: '$first → $next 에서 갇힌다',
          );
        }
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

  group('서버로 보낼 날짜', () {
    // 요일만으로는 서버가 어느 주를 말하는지 알 수 없다 — 날짜로 바꿔 보낸다.
    // 기간스타일 모드의 weekendBridge는 금·토·일/토·일·월 두 조합만 담을 수
    // 있어 목·금·토나 일·월·화를 표현하지 못한다
    test('오늘 이후 가장 가까운 시작 요일을 찾는다', () {
      // 2026-08-18 은 화요일
      final today = DateTime(2026, 8, 18);
      const days = WeekendDays(startWeekday: thu, days: 3);

      expect(days.firstStartDate(today), DateTime(2026, 8, 20), reason: '목');
      expect(days.lastDate(today), DateTime(2026, 8, 22), reason: '토');
    });

    test('오늘이 그 요일이면 다음 주로 잡는다', () {
      // 오늘 떠나라는 추천은 짐 쌀 시간이 없다
      final tuesday = DateTime(2026, 8, 18);
      const days = WeekendDays(startWeekday: tue, days: 2);

      expect(days.firstStartDate(tuesday), DateTime(2026, 8, 25));
    });

    test('주를 넘어가는 범위도 날짜로는 이어진다', () {
      // 일·월·화 — 요일은 감싸지만 날짜는 그냥 다음 날이다
      final today = DateTime(2026, 8, 18); // 화
      const days = WeekendDays(startWeekday: sun, days: 3);

      expect(days.firstStartDate(today), DateTime(2026, 8, 23), reason: '일');
      expect(days.lastDate(today), DateTime(2026, 8, 25), reason: '화');
    });

    test('월말을 넘어가도 날짜가 맞는다', () {
      // 2026-08-30 은 일요일 — 3일이면 9월로 넘어간다
      final today = DateTime(2026, 8, 26); // 수
      const days = WeekendDays(startWeekday: sun, days: 3);

      expect(days.firstStartDate(today), DateTime(2026, 8, 30));
      expect(days.lastDate(today), DateTime(2026, 9, 1));
    });

    test('마지막 요일을 계산한다', () {
      expect(const WeekendDays(startWeekday: thu, days: 3).endWeekday, sat);
    });
  });
}
