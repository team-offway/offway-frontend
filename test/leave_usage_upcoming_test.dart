import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';

/// 아직 떠나지 않은 여행은 '사용 내역'이 아니다.
///
/// 서버가 코스 확정 즉시 연차를 깎으면서 내역 날짜에 **여행 날짜**를 넣는다.
/// 그래서 D-10 여행이 사용 내역에 미리 들어앉는다 — 다녀오지도 않은 여행이
/// "썼다"고 적혀 있으면 사용자가 잘못된 기록으로 읽는다.
void main() {
  final today = DateTime(2026, 8, 18);

  LeaveUsage usage({required DateTime usedOn, int? courseId}) => LeaveUsage(
    id: 1,
    usedOn: usedOn,
    days: 2,
    courseId: courseId,
    reason: courseId == null ? '개인 사유' : '코스 확정',
  );

  group('예정 여부', () {
    test('내일 떠나는 여행은 예정이다', () {
      final trip = usage(usedOn: DateTime(2026, 8, 19), courseId: 7);
      expect(trip.isUpcoming(today), isTrue);
    });

    test('D-10 여행은 예정이다', () {
      // 스크린샷의 그 건 — 2026.08.27, 오늘은 8.18
      final trip = usage(usedOn: DateTime(2026, 8, 27), courseId: 7);
      expect(trip.isUpcoming(today), isTrue);
    });

    test('오늘 떠난 여행은 예정이 아니다', () {
      // 오늘 떠났으면 그 연차는 쓴 것이다
      final trip = usage(usedOn: today, courseId: 7);
      expect(trip.isUpcoming(today), isFalse);
    });

    test('지난 여행은 예정이 아니다', () {
      final trip = usage(usedOn: DateTime(2026, 8, 10), courseId: 7);
      expect(trip.isUpcoming(today), isFalse);
    });

    test('같은 날이면 시각이 달라도 예정이 아니다', () {
      // 날짜만 견준다 — 시각까지 보면 같은 날이 예정으로 잡힌다
      final trip = usage(usedOn: DateTime(2026, 8, 18, 23, 59), courseId: 7);
      expect(trip.isUpcoming(today), isFalse);
    });
  });

  group('무엇을 거르나', () {
    /// leaveUsagesProvider가 쓰는 것과 같은 규칙
    List<LeaveUsage> visible(List<LeaveUsage> all) => [
      for (final u in all)
        if (!(u.fromCourse && u.isUpcoming(today))) u,
    ];

    test('예정된 코스 차감만 사라진다', () {
      final past = usage(usedOn: DateTime(2026, 8, 10), courseId: 1);
      final upcoming = usage(usedOn: DateTime(2026, 8, 27), courseId: 2);

      expect(visible([past, upcoming]), [past]);
    });

    test('직접 등록한 내역은 미래여도 남는다', () {
      // 사용자가 스스로 "그날 연차 쓴다"고 적은 것이다 —
      // 앞당겨 깎이는 것은 코스 차감뿐이다
      final planned = usage(usedOn: DateTime(2026, 9, 1));
      expect(planned.fromCourse, isFalse);
      expect(visible([planned]), [planned]);
    });

    test('되돌린 내역(음수)도 규칙은 같다', () {
      final canceled = LeaveUsage(
        id: 2,
        usedOn: DateTime(2026, 8, 10),
        days: -2,
        courseId: 3,
      );
      expect(visible([canceled]), [canceled]);
    });

    test('전부 예정이면 목록이 빈다', () {
      final upcoming = usage(usedOn: DateTime(2026, 8, 27), courseId: 2);
      expect(visible([upcoming]), isEmpty);
    });
  });
}
