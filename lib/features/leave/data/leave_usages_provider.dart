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

/// 화면에 뿌릴 사용 내역.
///
/// **아직 떠나지 않은 여행은 뺀다.** 서버가 코스 확정 즉시 연차를 깎으면서
/// 내역 날짜에 여행 날짜를 넣어, D-10 여행이 '사용 내역'에 미리 들어앉는다.
/// 다녀오지도 않은 여행이 "썼다"고 적혀 있으면 사용자는 잘못된 기록으로
/// 읽는다 — 되돌리려 들거나, 남은 연차를 잘못 센다.
///
/// 서버에 차감 시점을 여행 종료 뒤로 옮겨 달라고 요청해 두었다
/// (`docs/백엔드-요청-연차차감시점.md`). 그때가 오면 걸러질 항목이 없어져
/// 이 필터는 저절로 무해해진다.
///
/// 서버 내역에는 `courseId`만 있고 코스 이름이 없다. 목록에 "정선 여행"처럼
/// 보여줘야 하므로 내 코스 목록에서 이름을 찾아 이어붙인다.
/// 코스를 못 불러와도 내역 자체는 보여준다.
final leaveUsagesProvider = FutureProvider.autoDispose<List<LeaveUsage>>((
  ref,
) async {
  final leave = await ref.watch(myLeaveProvider.future);
  // 직접 등록한 내역은 사용자가 스스로 쓴 날을 적은 것이라 미래여도 그대로 둔다.
  // 앞당겨 깎이는 것은 코스 차감뿐이다
  final usages = [
    for (final u in leave.usages)
      if (!(u.fromCourse && u.isUpcoming())) u,
  ];
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
