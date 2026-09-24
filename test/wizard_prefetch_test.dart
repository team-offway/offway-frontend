import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/course_wizard/application/available_time_provider.dart';
import 'package:offway/features/course_wizard/application/course_wizard_provider.dart';
import 'package:offway/features/course_wizard/data/region_recommend_repository.dart';
import 'package:offway/features/course_wizard/presentation/density_screen.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 후보 추천을 **밀도 화면에서 미리** 띄운다(#391).
///
/// 밀도는 가용시간·추천 어디에도 쓰이지 않는다. 사용자가 밀도를 고르는 사이
/// 두 왕복을 끝내 후보 화면의 로딩을 줄인다. 대신 밀도를 바꿀 때마다 다시
/// 묻지 않게 가용시간은 요청에 쓰는 값만 본다.
class _LeaveRepository implements LeaveRepository {
  int availableTimeCalls = 0;

  @override
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async {
    availableTimeCalls++;
    final start = DateTime(2026, 10, 1);
    return (
      startDate: start,
      endDate: start,
      travelDays: 1,
      consumedLeaveDays: 1.0,
      maxReachMinutes: 180,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecommendRepository implements RegionRecommendRepository {
  int calls = 0;

  @override
  Future<({List<Map<String, dynamic>> regions, List<DataSource> sources})>
  recommend({
    required String? originCode,
    required String transport,
    required int maxReachMinutes,
  }) async {
    calls++;
    return (regions: <Map<String, dynamic>>[], sources: <DataSource>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('밀도를 바꿔도 가용시간을 다시 묻지 않는다', () async {
    final leave = _LeaveRepository();
    final container = ProviderContainer(
      overrides: [leaveRepositoryProvider.overrideWithValue(leave)],
    );
    addTearDown(container.dispose);
    final wizard = container.read(courseWizardProvider.notifier);
    wizard.selectPeriodStyle(PeriodStyle.dayTrip);
    wizard.selectTransport(TransportMode.car);

    container.listen(availableTimeProvider, (_, _) {});
    await container.read(availableTimeProvider.future);
    expect(leave.availableTimeCalls, 1);

    wizard.selectDensity(ScheduleDensity.relaxed);
    wizard.selectDensity(ScheduleDensity.packed);
    await container.read(availableTimeProvider.future);
    expect(leave.availableTimeCalls, 1);

    // 요청에 쓰는 값이 바뀌면 다시 묻는다
    wizard.selectTransport(TransportMode.publicTransit);
    await container.read(availableTimeProvider.future);
    expect(leave.availableTimeCalls, 2);
  });

  testWidgets('밀도 화면에 들어오면 후보 추천을 미리 띄운다', (tester) async {
    final leave = _LeaveRepository();
    final recommend = _RecommendRepository();
    final container = ProviderContainer(
      overrides: [
        leaveRepositoryProvider.overrideWithValue(leave),
        regionRecommendRepositoryProvider.overrideWithValue(recommend),
      ],
    );
    addTearDown(container.dispose);
    final wizard = container.read(courseWizardProvider.notifier);
    wizard.selectPeriodStyle(PeriodStyle.dayTrip);
    wizard.selectTransport(TransportMode.car);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DensityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 밀도를 고르기 전에 이미 추천을 받았다
    expect(recommend.calls, 1);

    // 밀도를 골라도 다시 부르지 않는다
    await tester.tap(find.text('널널한 일정'));
    await tester.pumpAndSettle();
    expect(recommend.calls, 1);
    expect(leave.availableTimeCalls, 1);
  });
}
