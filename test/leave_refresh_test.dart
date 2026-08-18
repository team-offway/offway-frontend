import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 연차를 바꾼 뒤 홈과 내 연차가 **함께** 다시 읽히는지 고정한다.
///
/// 한쪽만 비우는 실수가 반복됐다 — 등록은 홈만, 삭제는 내 연차만 비웠다(#99).
/// 그래서 등록하고 돌아와도 내 연차가 옛 값이었다.
class _FakeRepository extends LeaveRepository {
  _FakeRepository() : super(Dio());

  /// 서버가 들고 있는 잔여 일수 — addUsage가 줄인다
  double remaining = 10;

  /// fetchMyLeave가 불린 횟수
  int fetched = 0;

  @override
  Future<void> addUsage({
    required DateTime usedOn,
    required double days,
    String? reason,
    int? courseId,
  }) async {
    remaining -= days;
  }

  @override
  Future<MyLeave> fetchMyLeave() async {
    fetched++;
    return MyLeave(
      totalDays: 10,
      usedDays: 10 - remaining,
      remainingDays: remaining,
      usages: const [],
    );
  }
}

void main() {
  late _FakeRepository repository;

  setUp(() => repository = _FakeRepository());

  /// [invalidateLeaveData]는 WidgetRef를 받으므로 위젯 안에서 불러야 한다.
  Future<WidgetRef> pumpRef(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [leaveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('연차를 바꾸면 내 연차가 새 값을 읽는다', (tester) async {
    final container = containerWith();

    // 내 연차는 autoDispose다 — read만 하면 구독이 곧 닫혀, 무효화 없이도
    // 다시 읽힌다. 그러면 이 테스트가 무효화를 검사하지 못한다
    final sub = container.listen(myLeaveProvider, (_, _) {});
    addTearDown(sub.close);

    expect((await container.read(myLeaveProvider.future)).remainingDays, 10);

    final ref = await pumpRef(tester, container);
    await repository.addUsage(usedOn: DateTime(2026, 8, 20), days: 3);
    invalidateLeaveData(ref);
    await tester.pump();

    expect((await container.read(myLeaveProvider.future)).remainingDays, 7);
  });

  testWidgets('무효화하지 않으면 옛 값이 그대로다', (tester) async {
    final container = containerWith();
    final sub = container.listen(myLeaveProvider, (_, _) {});
    addTearDown(sub.close);

    expect((await container.read(myLeaveProvider.future)).remainingDays, 10);

    // 서버 값만 바꾸고 무효화는 하지 않는다
    await repository.addUsage(usedOn: DateTime(2026, 8, 20), days: 3);

    expect((await container.read(myLeaveProvider.future)).remainingDays, 10);
  });

  testWidgets('사용 내역도 함께 다시 읽힌다', (tester) async {
    final container = containerWith();
    final sub = container.listen(leaveUsagesProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(leaveUsagesProvider.future);
    final before = repository.fetched;

    final ref = await pumpRef(tester, container);
    // leaveUsagesProvider는 myLeaveProvider를 watch하므로 따라 읽힌다
    invalidateLeaveData(ref);
    await tester.pump();
    await container.read(leaveUsagesProvider.future);

    expect(repository.fetched, greaterThan(before));
  });
}
