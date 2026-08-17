import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/data/trip_outcome_snooze_storage.dart';

/// 서버가 준 목록에서 **지금 물어볼 여행 하나**를 고르는 규칙.
///
/// 끝났는지·답했는지·차감했는지는 서버가 거른다. 앱이 더 거르는 것은
/// '오늘 미뤘는가' 하나다.
class _FakeCourseRepository extends CourseRepository {
  _FakeCourseRepository(this.trips, {this.fails = false}) : super(Dio());

  final List<Map<String, dynamic>> trips;
  final bool fails;

  @override
  Future<({double? remainingDays, List<Map<String, dynamic>> trips})>
  pendingTrips() async {
    if (fails) {
      throw const ApiException(status: 500, code: 'X', detail: '서버 오류');
    }
    return (remainingDays: 10.0, trips: trips);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Map<String, dynamic> trip({
    required int courseId,
    required String endDate,
    String startDate = '2026-08-10',
    String? regionName = '정선군',
  }) => {
    'courseId': courseId,
    'regionName': regionName,
    'travelDate': startDate,
    'travelEndDate': endDate,
    'consumedLeaveDays': 3.0,
  };

  ProviderContainer containerWith(
    List<Map<String, dynamic>> trips, {
    bool fails = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        courseRepositoryProvider.overrideWithValue(
          _FakeCourseRepository(trips, fails: fails),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('서버가 준 여행이 없으면 묻지 않는다', () async {
    final container = containerWith(const []);
    expect(await container.read(pendingTripProvider.future), isNull);
  });

  test('여행이 있으면 그 여행을 묻는다', () async {
    final container = containerWith([
      trip(courseId: 12, endDate: '2026-08-12'),
    ]);

    final pending = await container.read(pendingTripProvider.future);
    expect(pending?.courseId, 12);
    expect(pending?.title, '정선 여행, 다녀오셨나요?');
  });

  test('여러 건이면 가장 오래 밀린 것부터 묻는다', () async {
    // 밀린 여행이 셋이면 모달이 셋 연달아 뜬다 — 한 번에 하나만 묻고
    // 나머지는 다음 진입으로 넘긴다
    final container = containerWith([
      trip(courseId: 2, endDate: '2026-08-14'),
      trip(courseId: 1, endDate: '2026-08-02'),
      trip(courseId: 3, endDate: '2026-08-20'),
    ]);

    final pending = await container.read(pendingTripProvider.future);
    expect(pending?.courseId, 1);
  });

  test('오늘 미룬 여행은 건너뛴다', () async {
    // '나중에 할게요 → 당일 재노출 X' (시안 노트)
    final container = containerWith([
      trip(courseId: 1, endDate: '2026-08-02'),
      trip(courseId: 2, endDate: '2026-08-14'),
    ]);
    await container.read(tripOutcomeSnoozeProvider).snooze(1, DateTime.now());

    final pending = await container.read(pendingTripProvider.future);
    expect(pending?.courseId, 2, reason: '미룬 1번을 건너뛰고 다음을 묻는다');
  });

  test('전부 미뤘으면 오늘은 묻지 않는다', () async {
    final container = containerWith([trip(courseId: 1, endDate: '2026-08-02')]);
    await container.read(tripOutcomeSnoozeProvider).snooze(1, DateTime.now());

    expect(await container.read(pendingTripProvider.future), isNull);
  });

  test('어제 미룬 것은 오늘 다시 묻는다', () async {
    // '다음 날 홈 진입 → 다시 노출' (시안 노트)
    final container = containerWith([trip(courseId: 1, endDate: '2026-08-02')]);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await container.read(tripOutcomeSnoozeProvider).snooze(1, yesterday);

    final pending = await container.read(pendingTripProvider.future);
    expect(pending?.courseId, 1);
  });

  test('날짜가 깨진 항목은 건너뛴다', () async {
    // 없는 날짜로 'N일 차감'을 물으면 안 된다
    final container = containerWith([
      {'courseId': 1, 'regionName': '정선군', 'consumedLeaveDays': 3.0},
      trip(courseId: 2, endDate: '2026-08-14'),
    ]);

    final pending = await container.read(pendingTripProvider.future);
    expect(pending?.courseId, 2);
  });

  test('조회가 실패하면 묻지 않는다', () async {
    // 물어보는 건 덤이지 홈의 본 기능이 아니다 — 오류 화면을 띄우지 않는다
    final container = containerWith(const [], fails: true);
    expect(await container.read(pendingTripProvider.future), isNull);
  });
}
