import '../../../core/utils/region_name.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../course/application/course_providers.dart';
import '../../onboarding/data/leave_repository.dart';
import '../domain/leave_usage.dart';
import '../../home/application/home_providers.dart';

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

/// 화면에 뿌릴 사용 내역.
///
/// 서버 내역에는 `courseId`만 있고 코스 이름이 없다. 목록에 "정선 여행"처럼
/// 보여줘야 하므로 내 코스 목록에서 이름을 찾아 이어붙인다.
/// 코스를 못 불러와도 내역 자체는 보여준다.
final leaveUsagesProvider = FutureProvider.autoDispose<List<LeaveUsage>>((
  ref,
) async {
  // **코스 목록을 먼저 띄워 두고** 내역을 기다린다(#393). 둘은 서로 필요
  // 없는데 차례로 기다리면 내역이 왕복 한 번만큼 늦게 뜬다. 내 코스 탭과 같은
  // 목록(`savedCoursesProvider('ALL')`)을 써서 이미 받아 둔 게 있으면 요청도
  // 없다. 여기서 오류가 나도 내역은 보여 줘야 하니 먼저 삼켜 두고(ignore)
  // 아래에서 기다릴 때 다시 받는다
  final coursesFuture = ref.watch(savedCoursesProvider('ALL').future)..ignore();
  final leave = await ref.watch(myLeaveProvider.future);
  // 순서는 서버가 정한다 — 등록 시각 내림차순(core #384). 예전에는 서버가
  // 사용일 순으로 줘서 앱이 id로 다시 정렬했는데, 그 임시 처방을 걷어냈다
  final usages = leave.usages;
  if (usages.every((u) => u.courseId == null)) return usages;

  try {
    final courses = await coursesFuture;
    final names = {
      for (final c in courses)
        if (c['id'] != null)
          c['id'].toString(): regionTripLabel(c['regionName'] as String?),
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
