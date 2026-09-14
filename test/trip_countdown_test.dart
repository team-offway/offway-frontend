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
    durationLabel: '당일치기',
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

  group('문구', () {
    test('앞둔 여행은 D-n 으로 적는다', () {
      expect(trip(start: DateTime(2026, 9, 23)).headline(now), '정선군 여행 D-3');
    });

    test('하루 앞이면 내일이라고 말한다 — D-1 보다 읽힌다', () {
      expect(trip(start: DateTime(2026, 9, 21)).headline(now), '내일 정선군 여행');
    });

    test('여행 중에는 며칠째인지 말한다', () {
      // 이미 떠나 온 사람에게 'D-0'은 알려 주는 것이 없다
      final t = trip(start: DateTime(2026, 9, 19), end: DateTime(2026, 9, 21));
      expect(t.headline(now), '정선군 여행 2일차');
    });

    test('첫날은 1일차다', () {
      final t = trip(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 22));
      expect(t.headline(now), '정선군 여행 1일차');
    });

    test('끝난 여행은 마쳤다고 말한다', () {
      final t = trip(start: DateTime(2026, 9, 17), end: DateTime(2026, 9, 18));
      expect(t.headline(now), '정선군 여행을 마쳤어요');
    });
  });

  group('기간 표기', () {
    test('당일치기는 하루만 적는다', () {
      expect(trip(start: DateTime(2026, 7, 26)).rangeLabel, '2026.7.26');
    });

    test('여러 날이면 끝날을 붙인다', () {
      final t = trip(start: DateTime(2026, 7, 26), end: DateTime(2026, 7, 28));
      expect(t.rangeLabel, '2026.7.26 - 7.28');
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
