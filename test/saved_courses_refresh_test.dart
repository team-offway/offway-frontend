import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';

/// 코스를 담은 뒤 목록이 다시 읽히는지 고정한다.
///
/// 무효화하지 않으면 방금 담은 코스가 목록에 없다 — 탭을 오갔다 와야
/// 보이는데, 사용자는 담기가 실패한 줄 안다.
class _FakeRepository extends CourseRepository {
  _FakeRepository() : super(Dio());

  /// 저장된 코스 수 — save가 늘린다
  int saved = 0;

  @override
  Future<({int courseId, String? shareToken})> save(
    Map<String, dynamic> payload,
  ) async {
    saved++;
    return (courseId: saved, shareToken: null);
  }

  @override
  Future<List<Map<String, dynamic>>> savedCourseCards({
    String scope = 'ALL',
  }) async => [
    for (var i = 0; i < saved; i++) {'courseId': i + 1, 'regionName': '정선'},
  ];
}

void main() {
  ProviderContainer containerWith(_FakeRepository repository) {
    final container = ProviderContainer(
      overrides: [courseRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('담은 뒤 무효화하면 목록에 새 코스가 보인다', () async {
    final repository = _FakeRepository();
    final container = containerWith(repository);

    expect(await container.read(savedCoursesProvider('ALL').future), isEmpty);

    await repository.save(const {});
    container.invalidate(savedCoursesProvider);

    expect(
      await container.read(savedCoursesProvider('ALL').future),
      hasLength(1),
    );
  });

  test('무효화하지 않으면 옛 목록이 그대로다', () async {
    // 무효화를 빼먹었을 때 사용자가 무엇을 보는지 적어 둔다
    final repository = _FakeRepository();
    final container = containerWith(repository);

    expect(await container.read(savedCoursesProvider('ALL').future), isEmpty);
    await repository.save(const {});

    expect(await container.read(savedCoursesProvider('ALL').future), isEmpty);
  });

  test('서브탭이 달라도 함께 다시 읽힌다', () async {
    // 목록은 scope별 family다 — 담기는 ALL·UPCOMING 양쪽에 영향을 준다
    final repository = _FakeRepository();
    final container = containerWith(repository);

    await container.read(savedCoursesProvider('ALL').future);
    await container.read(savedCoursesProvider('UPCOMING').future);

    await repository.save(const {});
    container.invalidate(savedCoursesProvider);

    expect(
      await container.read(savedCoursesProvider('UPCOMING').future),
      hasLength(1),
    );
  });
}
