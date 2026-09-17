import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';

/// 장소 운영 정보는 **한 번만 받는다**(#315).
///
/// 여행 당일 코스 상세가 장소마다 이 값을 부르는데, 응답이 장소 상세 전문이라
/// 하루 6~8곳이면 그만큼 나간다. 날짜 탭을 오가거나 화면을 나갔다 들어올
/// 때마다 되풀이됐다.
class _FakeRepository extends CourseRepository {
  _FakeRepository({this.fails = 0}) : super(Dio());

  /// `poiSchedule` 이 서버까지 간 횟수
  int calls = 0;

  /// 앞의 몇 번을 실패시킬지 — 실패가 캐시되지 않는 것을 보려고
  int fails;

  @override
  Future<({String? useTime, String? restDate})> poiSchedule(
    String contentId,
  ) async {
    calls++;
    if (fails > 0) {
      fails--;
      throw Exception('일시적인 통신 실패');
    }
    return (useTime: '09:00 - 18:00', restDate: '매주 월요일');
  }
}

void main() {
  ProviderContainer containerWith(_FakeRepository repository) {
    final container = ProviderContainer(
      overrides: [courseRepositoryProvider.overrideWithValue(repository)],
      // 자동 재시도를 끈다 — 여기서 재는 것은 **캐시**이지 재시도가 아니다.
      // 켜 두면 실패가 조용히 재시도로 메워져 호출 횟수를 읽을 수 없다
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  test('구독이 끊겨도 다시 받지 않는다 — 화면을 나갔다 와도 한 번이다', () async {
    final repository = _FakeRepository();
    final container = containerWith(repository);

    // 화면이 열려 값을 읽는다
    final first = container.listen(poiScheduleProvider('126508'), (_, _) {});
    await container.read(poiScheduleProvider('126508').future);
    expect(repository.calls, 1);

    // 화면을 떠난다 — autoDispose 라면 여기서 버려진다
    first.close();
    await Future<void>.delayed(Duration.zero);

    // 다시 들어온다
    container.listen(poiScheduleProvider('126508'), (_, _) {});
    await container.read(poiScheduleProvider('126508').future);

    expect(repository.calls, 1, reason: '같은 장소를 다시 받았다 — keepAlive 를 확인할 것');
  });

  test('장소가 다르면 각각 받는다', () async {
    final repository = _FakeRepository();
    final container = containerWith(repository);

    container.listen(poiScheduleProvider('1'), (_, _) {});
    container.listen(poiScheduleProvider('2'), (_, _) {});
    await container.read(poiScheduleProvider('1').future);
    await container.read(poiScheduleProvider('2').future);

    expect(repository.calls, 2);
  });

  test('실패는 붙들지 않는다 — 다음에 다시 시도한다', () async {
    // 통신이 한 번 실패했다고 그 장소의 안내가 세션 내내 비어 있으면 안 된다
    final repository = _FakeRepository(fails: 1);
    final container = containerWith(repository);

    final first = container.listen(poiScheduleProvider('1'), (_, _) {});
    await expectLater(
      container.read(poiScheduleProvider('1').future),
      throwsA(isA<Exception>()),
    );
    expect(repository.calls, 1);

    first.close();
    await Future<void>.delayed(Duration.zero);

    // 다시 들어오면 재시도하고, 이번엔 성공한다
    container.listen(poiScheduleProvider('1'), (_, _) {});
    final schedule = await container.read(poiScheduleProvider('1').future);

    expect(repository.calls, 2);
    expect(schedule.useTime, '09:00 - 18:00');
  });
}
