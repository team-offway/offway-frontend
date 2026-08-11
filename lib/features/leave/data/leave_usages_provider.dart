import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../course/data/course_repository.dart';
import '../../onboarding/data/leave_repository.dart';
import '../domain/leave_usage.dart';

/// 내 연차 — 잔여 일수와 사용 내역 (`GET /leaves/me`)
final myLeaveProvider = FutureProvider.autoDispose<MyLeave>(
  (ref) => ref.watch(leaveRepositoryProvider).fetchMyLeave(),
);

/// 화면에 뿌릴 사용 내역.
///
/// 서버 내역에는 `courseId`만 있고 코스 이름이 없다. 목록에 "정선 여행"처럼
/// 보여줘야 하므로 내 코스 목록에서 이름을 찾아 이어붙인다.
/// 코스를 못 불러와도 내역 자체는 보여준다.
final leaveUsagesProvider = FutureProvider.autoDispose<List<LeaveUsage>>((
  ref,
) async {
  final leave = await ref.watch(myLeaveProvider.future);
  final usages = leave.usages;
  if (usages.every((u) => u.courseId == null)) return usages;

  try {
    final courses = await ref
        .watch(courseRepositoryProvider)
        .savedCourseCards();
    final names = {
      for (final c in courses)
        if (c['id'] != null) c['id'].toString(): c['regionName'] as String?,
    };
    return [
      for (final u in usages)
        u.courseId == null ? u : u.copyWith(courseName: names['${u.courseId}']),
    ];
  } on Exception {
    // 코스 이름을 못 채워도 내역은 그대로 보여준다
    return usages;
  }
});
