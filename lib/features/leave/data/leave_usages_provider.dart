import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../course/data/course_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../onboarding/data/leave_repository.dart';
import '../domain/leave_usage.dart';

/// 연차가 바뀐 뒤 다시 읽어야 할 것들을 한꺼번에 비운다.
///
/// 등록·삭제·"다녀오셨나요?" 어디서 바뀌든 **보이는 곳은 같다** — 홈 최상단의
/// '남은 연차'와 내 연차 화면이다. 그런데 화면마다 손으로 챙기다 보니 한쪽씩
/// 빠뜨려 왔다. 등록은 홈만, 삭제는 내 연차만 비우는 식이었다(#99).
///
/// [leaveUsagesProvider]는 [myLeaveProvider]를 watch하므로 따로 비우지 않아도
/// 함께 다시 읽힌다.
void invalidateLeaveData(WidgetRef ref) {
  ref
    ..invalidate(homeSnapshotProvider)
    ..invalidate(myLeaveProvider);
}

/// 내 연차 — 잔여 일수와 사용 내역 (`GET /leaves/me`)
final myLeaveProvider = FutureProvider.autoDispose<MyLeave>(
  (ref) => ref.watch(leaveRepositoryProvider).fetchMyLeave(),
);

/// 내역을 **등록한 순서**로, 최근 것이 위에 오게 늘어놓는다.
///
/// 서버는 사용일(`usedOn`) 내림차순으로 준다. 그러면 미래 날짜로 잡아 둔
/// 내역이 늘 맨 위에 붙어, 방금 등록한 것이 아래로 숨는다 — 사용자가 찾는
/// 건 "방금 한 일"이다. 응답에 등록 시각은 없지만 `id`가 등록 순서대로
/// 매겨지므로 그걸로 정렬한다. 코스 확정으로 서버가 만든 행도 같은 규칙이다.
List<LeaveUsage> sortUsagesByRegistration(List<LeaveUsage> usages) =>
    [...usages]..sort((a, b) => b.id.compareTo(a.id));

/// 화면에 뿌릴 사용 내역.
///
/// 서버 내역에는 `courseId`만 있고 코스 이름이 없다. 목록에 "정선 여행"처럼
/// 보여줘야 하므로 내 코스 목록에서 이름을 찾아 이어붙인다.
/// 코스를 못 불러와도 내역 자체는 보여준다.
final leaveUsagesProvider = FutureProvider.autoDispose<List<LeaveUsage>>((
  ref,
) async {
  final leave = await ref.watch(myLeaveProvider.future);
  final usages = sortUsagesByRegistration(leave.usages);
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
