import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/trip_activity/domain/trip_countdown.dart';

/// 잠금화면·다이나믹 아일랜드에 띄울 여행 D-day.
///
/// **코스에는 시각 정보가 없다** — 장소마다 몇 시인지 서버가 주지 않으므로
/// 날짜로 답할 수 있는 것만 담는다.
void main() {
  TripCountdown trip({
    required DateTime start,
    DateTime? end,
    String region = '정선군',
  }) => TripCountdown(
    courseId: '1',
    regionName: region,
    startDate: start,
    endDate: end ?? start,
  );

  final now = DateTime(2026, 9, 20);

  group('남은 날 세기', () {
    test('오늘이 여행 첫날이면 0이다', () {
      expect(trip(start: DateTime(2026, 9, 20)).daysUntil(now), 0);
    });

    test('사흘 뒤면 3이다', () {
      expect(trip(start: DateTime(2026, 9, 23)).daysUntil(now), 3);
    });

    test('지난 여행은 음수다', () {
      expect(trip(start: DateTime(2026, 9, 18)).daysUntil(now), -2);
    });

    test('시각이 달라도 달력 하루로 센다', () {
      // difference().inDays 는 경과 시간을 24로 나눠 서머타임에서 어긋난다
      final t = trip(start: DateTime(2026, 9, 23, 23, 59));
      expect(t.daysUntil(DateTime(2026, 9, 20, 0, 1)), 3);
    });
  });

  group('재료', () {
    // **문구는 여기서 만들지 않는다.** 네이티브 ContentState 가 조립한다
    // (core #577 B안). 앱은 서버가 자정에 보내는 것과 같은 재료만 넘긴다 —
    // 남은 날·며칠째 **둘 중 하나만** 값이 있다
    test('출발 전에는 남은 날만 있다', () {
      final t = trip(start: DateTime(2026, 9, 23));
      expect(t.daysLeft(now), 3);
      expect(t.dayNth(now), isNull);
    });

    test('여행 중에는 며칠째만 있다', () {
      final t = trip(start: DateTime(2026, 9, 19), end: DateTime(2026, 9, 21));
      expect(t.daysLeft(now), isNull);
      expect(t.dayNth(now), 2);
    });

    test('출발 당일은 1일차다 — 0일차는 없다', () {
      // 이미 떠나 온 사람에게 D-0 은 알려 주는 것이 없다
      final t = trip(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 22));
      expect(t.daysLeft(now), isNull);
      expect(t.dayNth(now), 1);
    });

    test('날짜는 yyyy-MM-dd 로 넘긴다 — 시각·시간대를 싣지 않는다', () {
      // 서버·네이티브가 같은 표기를 읽는다. 한 자리 월·일도 0 을 채운다
      expect(TripCountdown.isoDate(DateTime(2026, 9, 3)), '2026-09-03');
      expect(
        TripCountdown.isoDate(DateTime(2026, 12, 25, 15, 30)),
        '2026-12-25',
      );
    });
  });

  group('경계', () {
    test('마지막날도 여행 중이다', () {
      // isOngoing 이 마지막날을 빼면 잠금화면이 그날 사라진다
      final t = trip(start: DateTime(2026, 9, 18), end: DateTime(2026, 9, 20));
      expect(t.isOngoing(now), isTrue);
      expect(t.isPast(now), isFalse);
      expect(t.dayNth(now), 3);
    });

    test('날짜가 뒤집힌 데이터는 고르지 않는다', () {
      // endDate 가 앞서면 isOngoing·isPast 둘 다 false 다 — 막지 않으면
      // 음수인 채로 뽑혀 'D--3' 이 잠금화면에 나간다
      final broken = trip(
        start: DateTime(2026, 9, 17),
        end: DateTime(2026, 9, 16),
      );
      expect(TripCountdown.pick([broken], now), isNull);
    });

    test('앞으로 올 여행도 날짜가 뒤집혔으면 고르지 않는다', () {
      // 하한(daysUntil >= 0)만으로는 못 막는다 — 출발이 미래라 통과해
      // 버리고, 엉뚱한 기간이 잠금화면에 나간다
      final broken = trip(
        start: DateTime(2026, 9, 25),
        end: DateTime(2026, 9, 24),
      );
      expect(TripCountdown.pick([broken], now), isNull);
    });

    test('UTC 표기로 와도 로컬 날짜로 센다', () {
      // 서버가 '2026-09-22T15:00:00Z' 같은 UTC 표기로 바꾸면 isUtc 인
      // DateTime 이 만들어져, 한국(UTC+9)에서는 로컬 9/23 인데 날짜가
      // 9/22 로 셈해진다.
      //
      // **기대값을 날짜로 박지 않는다** — CI 는 UTC 로 돌아 한국 기준
      // 숫자를 적으면 여기서만 갈린다. 변환 규칙 자체를 확인한다
      const raw = '2026-09-22T15:00:00Z';
      final t = TripCountdown.tryFrom({
        'courseId': '7',
        'regionName': '정선군',
        'startDate': raw,
      });

      final expected = DateUtils.dateOnly(DateTime.parse(raw).toLocal());
      expect(t!.startDate, expected);
      // 로컬 자정으로 맞춰 둬야 calendarDaysBetween 이 하루를 안 흘린다
      expect(t.startDate.isUtc, isFalse);
      expect([t.startDate.hour, t.startDate.minute], [0, 0]);
    });
  });

  group('어느 여행을 띄울까', () {
    test('여행 중인 것이 가장 급하다', () {
      final picked = TripCountdown.pick([
        trip(start: DateTime(2026, 9, 22), region: '가평군'),
        trip(
          start: DateTime(2026, 9, 19),
          end: DateTime(2026, 9, 21),
          region: '정선군',
        ),
      ], now);
      expect(picked?.regionName, '정선군');
    });

    test('여행 중이 없으면 가장 가까운 예정이다', () {
      final picked = TripCountdown.pick([
        trip(start: DateTime(2026, 9, 25), region: '홍천군'),
        trip(start: DateTime(2026, 9, 22), region: '가평군'),
      ], now);
      expect(picked?.regionName, '가평군');
    });

    test('지난 여행은 고르지 않는다', () {
      final picked = TripCountdown.pick([
        trip(start: DateTime(2026, 9, 10), end: DateTime(2026, 9, 11)),
      ], now);
      expect(picked, isNull);
    });

    test('너무 먼 여행은 띄우지 않는다 — 잠금화면만 차지한다', () {
      final picked = TripCountdown.pick([
        trip(start: DateTime(2026, 11, 1)),
      ], now);
      expect(picked, isNull);
    });

    test('D-5 부터 띄운다 — 그 밖은 고르지 않는다', () {
      // 기본값을 못 박는다. 경계가 조용히 늘어나면 잠금화면에 먼 여행이
      // 앉아 있게 된다
      expect(
        TripCountdown.pick([trip(start: DateTime(2026, 9, 25))], now),
        isNotNull,
      );
      expect(
        TripCountdown.pick([trip(start: DateTime(2026, 9, 26))], now),
        isNull,
      );
    });

    test('며칠 전부터 띄울지는 바꿀 수 있다', () {
      final trips = [trip(start: DateTime(2026, 10, 5))];
      expect(TripCountdown.pick(trips, now), isNull);
      expect(TripCountdown.pick(trips, now, within: 30), isNotNull);
    });

    test('띄울 것이 없으면 null 이다', () {
      expect(TripCountdown.pick([], now), isNull);
    });
  });

  group('저장 코스 카드에서 만들기', () {
    test('날짜가 있으면 만든다', () {
      final t = TripCountdown.tryFrom({
        'courseId': '7',
        'regionName': '태안군',
        'startDate': '2026-09-22',
        'endDate': '2026-09-23',
        'durationLabel': '1박 2일',
      });
      expect(t?.courseId, '7');
      expect(t?.regionName, '태안군');
      expect(t?.endDate, DateTime(2026, 9, 23));
    });

    test('일정 미확정(날짜 없음)이면 만들지 않는다', () {
      // 억지로 오늘로 치면 엉뚱한 여행이 잠금화면에 뜬다
      expect(
        TripCountdown.tryFrom({'courseId': '7', 'regionName': '태안군'}),
        isNull,
      );
    });

    test('끝날이 없으면 당일치기로 본다', () {
      final t = TripCountdown.tryFrom({
        'courseId': '7',
        'startDate': '2026-09-22',
      });
      expect(t?.endDate, DateTime(2026, 9, 22));
    });
  });
}
