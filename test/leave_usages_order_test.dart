import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';

/// 연차 사용 내역의 순서 — 사용일이 아니라 **등록한 순서**, 최근 것이 위.
void main() {
  test('사용일이 미래라도 나중에 등록한 것이 위로 온다', () {
    // 서버 순서(사용일 내림차순): 8/27 코스 건(id 3) → 8/24 직접 등록(id 5) → 8/20(id 2)
    final fromServer = [
      LeaveUsage(id: 3, usedOn: DateTime(2026, 8, 27), days: 2, courseId: 7),
      LeaveUsage(id: 5, usedOn: DateTime(2026, 8, 24), days: 2, reason: '여행'),
      LeaveUsage(id: 2, usedOn: DateTime(2026, 8, 20), days: 2, courseId: 4),
    ];

    final sorted = sortUsagesByRegistration(fromServer);

    // 가장 최근에 등록한 8/24 건(id 5)이 맨 위 — 사용일로 두면 8/27 뒤로 숨는다
    expect(sorted.map((u) => u.id), [5, 3, 2]);
  });

  test('원본 목록은 건드리지 않는다', () {
    final original = [
      LeaveUsage(id: 1, usedOn: DateTime(2026, 8, 1), days: 1),
      LeaveUsage(id: 2, usedOn: DateTime(2026, 8, 2), days: 1),
    ];
    sortUsagesByRegistration(original);
    expect(original.map((u) => u.id), [1, 2]);
  });
}
