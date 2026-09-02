import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_toast.dart';
import '../../leave/data/leave_usages_provider.dart' show invalidateLeaveData;
import '../application/pending_trip_provider.dart';
import '../data/course_repository.dart';
import '../data/trip_outcome_snooze_storage.dart';
import '../domain/pending_trip.dart';
import 'my_courses_screen.dart' show savedCoursesProvider;
import 'widgets/trip_outcome_dialog.dart';

/// "다녀오셨나요?" 모달을 화면에 붙인다.
///
/// 시안 노트가 **홈**과 **내 연차** 두 곳에서 띄우라고 한다. 답을 처리하는
/// 절차(서버 기록 → 미룸 정리 → 연차 다시 읽기 → 토스트)가 똑같으므로
/// 화면마다 옮겨 적지 않고 한 곳에 둔다.
///
/// 쓰는 쪽은 [build] 안에서 [watchTripOutcomePrompt]를 한 번 부르면 된다.
mixin TripOutcomePrompt<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// 이번 진입에서 이미 물었는지.
  ///
  /// 프로바이더가 다시 읽힐 때마다(연차 갱신 등) 모달이 또 뜨는 걸 막는다.
  /// '나중에 할게요'는 저장소가 하루를 기억하지만, 그 저장이 끝나기 전에
  /// 다음 프레임이 오면 같은 여행을 두 번 묻게 된다.
  bool _asked = false;

  /// 기록 토스트에 '보러가기'를 붙일지.
  ///
  /// 내 연차 화면은 그 버튼이 가리키는 곳이 자기 자신이라 끈다 —
  /// 눌러도 제자리인 버튼은 없느니만 못하다.
  bool get showsLeaveShortcut => true;

  /// 눌러서 들어온 "다녀오셨나요?" 알림이 가리키는 코스. 알림 없이 왔으면 null.
  ///
  /// **그 여행에 한해** [PendingTrip.askableFrom]을 다시 재지 않는다 — 알림이
  /// 곧 "지금 물어볼 때"라는 서버의 판단인데, 기기 시계가 몇 초 느리거나
  /// 시간대가 다르면 알림을 눌렀는데 모달이 안 뜨는 일이 생긴다.
  ///
  /// 다른 여행에는 적용하지 않는다. 프로바이더는 가장 오래 밀린 여행을
  /// 고르므로, 옛 알림을 뒤늦게 누른 아침에 어제 끝난 다른 여행이 걸리면
  /// 그 여행은 아직 물을 때가 아니다.
  int? get notificationCourseId => null;

  /// 물어볼 여행이 있으면 화면이 그려진 뒤 모달을 띄운다.
  ///
  /// [build] 안에서 부른다 — build 도중에는 `showDialog`를 열 수 없어
  /// 다음 프레임으로 미룬다.
  void watchTripOutcomePrompt() {
    // listen이 아니라 watch로 읽는다: 이 화면에 돌아왔을 때 이미 값이
    // 캐시돼 있으면 listen은 '바뀐 적 없다'며 부르지 않는다
    final trip = ref.watch(pendingTripProvider).value;
    if (trip == null || _asked) return;
    // 알림(다음 날 20시)보다 먼저 묻지 않는다 — 자정에 넘어온 여행은
    // 저녁까지 홈에 들어와도 조용하다. 그 여행의 알림을 눌러 왔을 때만 예외
    final fromItsNotification = trip.courseId == notificationCourseId;
    if (!fromItsNotification && !trip.isAskableAt(DateTime.now())) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_asked) _ask(trip);
    });
  }

  Future<void> _ask(PendingTrip trip) async {
    _asked = true;
    final answer = await showTripOutcomeDialog(context, trip: trip);
    if (!mounted) return;

    if (answer == TripOutcomeAnswer.later) {
      // 오늘만 접는다 — 내일 들어오면 다시 묻는다
      await ref
          .read(tripOutcomeSnoozeProvider)
          .snooze(trip.courseId, DateTime.now());
      return;
    }

    final visited = answer == TripOutcomeAnswer.visited;
    final double? remainingDays;
    try {
      remainingDays = await ref
          .read(courseRepositoryProvider)
          .answerTripOutcome(trip.courseId, visited: visited);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409(이미 답함)면 목록에서 빠지므로 다시 묻지 않는다.
      // 그 밖의 실패는 다음 진입에 다시 묻게 두고 알리기만 한다
      showAppToast(context, e.detail.isEmpty ? '기록하지 못했어요' : e.detail);
      return;
    }

    // 답을 받았으니 미룸 기록은 필요 없다
    await ref.read(tripOutcomeSnoozeProvider).clear(trip.courseId);
    if (!mounted) return;

    // 홈 최상단 '남은 연차'와 연차 화면을 즉시 고쳐 그린다 (시안 노트)
    invalidateLeaveData(ref);
    // 답을 했으니 다시 물어보지 않는다
    ref.invalidate(pendingTripProvider);
    // 내 코스 카드의 여행완료·미방문 칩이 이 답(leaveDeducted)으로 갈리므로
    // 목록도 다시 읽는다
    ref.invalidate(savedCoursesProvider);

    // 안 갔다고 답하면 바뀐 게 없다 — 알릴 것도 없다
    if (!visited) return;

    showAppToast(
      context,
      '${trip.shortRegionName ?? '이번'} 여행을 기록했어요.',
      detail: _deductionDetail(trip.consumedLeaveDays, remainingDays),
      kind: AppToastKind.success,
      // 시안 흐름: 토스트 → 내 연차. 줄어든 잔여 연차와 방금 기록이
      // 한 화면에 같이 있다
      actionLabel: showsLeaveShortcut ? '보러가기' : null,
      onAction: showsLeaveShortcut
          ? () => context.push(AppRoutes.myLeave)
          : null,
    );
  }

  /// `연차 3일을 사용해 10일 남았어요.`
  ///
  /// 깎은 연차가 없으면(주말·공휴일만 다녀온 여행) 아예 말하지 않는다 —
  /// 모달이 차감 안내를 접은 것과 같은 이유로, '0일을 사용'은 헛말이다.
  /// 서버가 남은 연차를 안 주면(연차를 설정한 적 없는 사용자) 뒷말을 뺀다 —
  /// '0일 남았어요'로 잘못 말하느니 쓴 만큼만 알린다.
  String? _deductionDetail(double used, double? remaining) {
    if (used <= 0) return null;
    final spent = '연차 ${formatLeaveDays(used)}일을 사용';
    if (remaining == null) return '$spent했어요.';
    return '$spent해 ${formatLeaveDays(remaining)}일 남았어요.';
  }
}
