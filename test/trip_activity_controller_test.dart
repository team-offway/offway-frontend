import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart'
    show savedCoursesProvider;
import 'package:offway/features/trip_activity/application/trip_activity_controller.dart';
import 'package:offway/features/trip_activity/data/trip_activity_service.dart';
import 'package:offway/features/trip_activity/domain/trip_countdown.dart';

/// 예정 코스를 읽어 **어느 여행을 잠금화면에 띄울지** 정하는 자리.
///
/// 고르는 규칙 자체는 [TripCountdown] 테스트가 잠근다. 여기서는 배선을 본다 —
/// 어느 범위를 읽는지, 띄울 것이 없을 때 내리는지.
class _FakeService implements TripActivityService {
  _FakeService({this.available = true});

  final bool available;
  TripCountdown? started;
  int endCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> start(TripCountdown trip, {DateTime? now}) async {
    started = trip;
  }

  @override
  Future<void> end() async => endCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 9, 20);

  Map<String, dynamic> card({
    required String id,
    required String start,
    String? end,
    String region = '정선군',
  }) => {
    'courseId': id,
    'regionName': region,
    'startDate': start,
    'endDate': ?end,
    'durationLabel': '당일치기',
  };

  ProviderContainer containerWith(
    List<Map<String, dynamic>> cards,
    _FakeService service,
  ) {
    final c = ProviderContainer(
      overrides: [
        tripActivityServiceProvider.overrideWithValue(service),
        savedCoursesProvider('UPCOMING').overrideWith((ref) async => cards),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('가장 가까운 예정 여행을 띄운다', () async {
    final service = _FakeService();
    final c = containerWith([
      card(id: '1', start: '2026-09-25', region: '홍천군'),
      card(id: '2', start: '2026-09-22', region: '가평군'),
    ], service);

    await c.read(tripActivityControllerProvider).sync(now: now);

    expect(service.started?.regionName, '가평군');
  });

  test('띄울 것이 없으면 떠 있던 것을 내린다', () async {
    // 끝난 여행이 잠금화면에 남아 있을 이유가 없다
    final service = _FakeService();
    final c = containerWith([], service);

    await c.read(tripActivityControllerProvider).sync(now: now);

    expect(service.started, isNull);
    expect(service.endCount, 1);
  });

  test('너무 먼 여행뿐이면 내린다', () async {
    final service = _FakeService();
    final c = containerWith([card(id: '1', start: '2026-12-01')], service);

    await c.read(tripActivityControllerProvider).sync(now: now);

    expect(service.started, isNull);
    expect(service.endCount, 1);
  });

  test('날짜 없는 코스는 건너뛴다 — 일정 미확정', () async {
    final service = _FakeService();
    final c = containerWith([
      {'courseId': '1', 'regionName': '태안군'},
      card(id: '2', start: '2026-09-22', region: '가평군'),
    ], service);

    await c.read(tripActivityControllerProvider).sync(now: now);

    expect(service.started?.regionName, '가평군');
  });

  test('기능을 못 쓰는 기기에서는 아무것도 하지 않는다', () async {
    // iOS 16.1 미만·안드로이드·사용자가 껐을 때
    final service = _FakeService(available: false);
    final c = containerWith([card(id: '1', start: '2026-09-22')], service);

    await c.read(tripActivityControllerProvider).sync(now: now);

    expect(service.started, isNull);
    expect(service.endCount, 0, reason: '내릴 것도 없다');
  });
}
