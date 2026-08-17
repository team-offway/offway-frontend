import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../data/course_repository.dart';
import '../data/trip_outcome_snooze_storage.dart';
import '../domain/pending_trip.dart';

/// 지금 홈에서 물어볼 지난 여행 — 없으면 null.
///
/// 서버가 준 목록(`GET /courses/pending-trips`)에서 **오늘 미뤄둔 것을 걷어내고**
/// 가장 오래된 여행 하나만 남긴다.
///
/// 하나만 묻는 이유: 밀린 여행이 셋이면 모달이 셋 연달아 뜬다. 홈에 들어온
/// 사람에게 문답을 시키는 화면이 되므로, 한 번에 하나만 묻고 나머지는
/// 다음 진입에 넘긴다.
///
/// 실패는 null로 삼킨다 — 물어보는 건 덤이지 홈의 본 기능이 아니다.
/// 연차를 아직 설정하지 않아 서버가 `remainingDays: null`을 줘도 묻긴 묻는다
/// (차감은 서버가 알아서 계산한다).
final pendingTripProvider = FutureProvider.autoDispose<PendingTrip?>((
  ref,
) async {
  final List<Map<String, dynamic>> raw;
  try {
    raw = (await ref.watch(courseRepositoryProvider).pendingTrips()).trips;
  } on ApiException {
    return null;
  }

  final snooze = ref.watch(tripOutcomeSnoozeProvider);
  final today = DateTime.now();

  final trips = raw.map(PendingTrip.tryParse).nonNulls.toList()
    // 서버 정렬을 믿지 않는다 — 오래 밀린 것부터 묻는다
    ..sort((a, b) => a.endDate.compareTo(b.endDate));

  for (final trip in trips) {
    if (!await snooze.isSnoozedToday(trip.courseId, today)) return trip;
  }
  return null;
});
