import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/application/course_providers.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 연차 사용 내역 — 내역과 코스 목록을 **동시에** 받는다(#393).
///
/// 둘은 서로 필요 없는데 차례로 기다려, 내역이 왕복 한 번만큼 늦게 떴다.
class _LeaveRepository extends LeaveRepository {
  _LeaveRepository(this.gate) : super(Dio());

  final Completer<void> gate;

  @override
  Future<MyLeave> fetchMyLeave() async {
    await gate.future;
    return MyLeave(
      totalDays: 15,
      usedDays: 2,
      remainingDays: 13,
      usages: [
        LeaveUsage(id: 1, usedOn: DateTime(2026, 9, 1), days: 2, courseId: 7),
      ],
    );
  }
}

void main() {
  test('내역을 기다리는 동안 코스 목록을 이미 부르고, 이름을 붙인다', () async {
    final gate = Completer<void>();
    var courseCalls = 0;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        leaveRepositoryProvider.overrideWithValue(_LeaveRepository(gate)),
        savedCoursesProvider.overrideWith((ref, scope) async {
          courseCalls++;
          return [
            {'id': '7', 'regionName': '정선군'},
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    container.listen(leaveUsagesProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    // 내역은 아직 안 왔는데 코스 목록은 이미 불렀다
    expect(courseCalls, 1);

    gate.complete();
    final usages = await container.read(leaveUsagesProvider.future);
    expect(usages.single.courseName, isNotNull);
    expect(courseCalls, 1);
  });

  test('코스 목록이 실패해도 내역은 그대로 보여 준다', () async {
    final gate = Completer<void>()..complete();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        leaveRepositoryProvider.overrideWithValue(_LeaveRepository(gate)),
        savedCoursesProvider.overrideWith(
          (ref, scope) =>
              Future<List<Map<String, dynamic>>>.error(Exception('500')),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(leaveUsagesProvider, (_, _) {});
    final usages = await container.read(leaveUsagesProvider.future);
    expect(usages.single.id, 1);
    expect(usages.single.courseName, isNull);
  });
}
