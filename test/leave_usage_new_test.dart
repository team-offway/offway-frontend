import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';

/// 연차 내역의 등록 시각(core #384)과 'New' 판정을 고정한다.
///
/// 시안: 등록 시점 기준 24시간 동안만 New, 이후 자동 소멸.
void main() {
  group('등록 시각 파싱', () {
    test('KST 오프셋 없는 시각을 읽는다', () {
      // 알림의 createdAt과 같은 규격이다 — 같은 파서를 쓴다
      final u = LeaveUsage.fromJson({
        'id': 57,
        'usedOn': '2026-05-08',
        'days': 1.0,
        'createdAt': '2026-09-01T14:03:22',
      });
      expect(u.createdAt, DateTime(2026, 9, 1, 14, 3, 22));
    });

    test('옛 내역은 없다 — 서버가 백필하지 않았다', () {
      final u = LeaveUsage.fromJson({
        'id': 1,
        'usedOn': '2026-05-08',
        'days': 1.0,
        'createdAt': null,
      });
      expect(u.createdAt, isNull);
    });

    test('키가 아예 없는 옛 서버 응답도 깨지지 않는다', () {
      final u = LeaveUsage.fromJson({
        'id': 1,
        'usedOn': '2026-05-08',
        'days': 1.0,
      });
      expect(u.createdAt, isNull);
    });

    test('코스 이름을 이어붙여도 등록 시각이 남는다', () {
      // copyWith가 이 필드를 빠뜨리면 코스 건만 New가 안 뜬다
      final u = LeaveUsage(
        id: 1,
        usedOn: DateTime(2026, 8, 1),
        days: 2,
        courseId: 7,
        createdAt: DateTime(2026, 9, 1, 10),
      ).copyWith(courseName: '정선 여행');
      expect(u.createdAt, DateTime(2026, 9, 1, 10));
    });
  });

  group('New 판정', () {
    final now = DateTime(2026, 9, 2, 12);
    LeaveUsage at(DateTime? created) => LeaveUsage(
      id: 1,
      usedOn: DateTime(2026, 8, 1),
      days: 1,
      createdAt: created,
    );

    test('등록한 지 24시간 안이면 새 것이다', () {
      expect(at(now.subtract(const Duration(hours: 23))).isNewAt(now), isTrue);
    });

    test('정확히 24시간이면 이미 지난 것이다', () {
      // 경계를 포함으로 두면 "24시간 동안만"이 "24시간 넘게"가 된다
      expect(at(now.subtract(const Duration(hours: 24))).isNewAt(now), isFalse);
    });

    test('사용일이 아니라 등록 시각으로 판정한다', () {
      // 지난달 쓴 연차를 방금 등록했다 — usedOn은 옛날이지만 New다
      expect(at(now.subtract(const Duration(minutes: 5))).isNewAt(now), isTrue);
    });

    test('등록 시각을 모르면 새 것으로 보지 않는다', () {
      expect(at(null).isNewAt(now), isFalse);
    });

    test('기기 시계가 앞서 등록 시각이 미래여도 새 것이다', () {
      // 방금 등록했는데 칩이 안 뜨는 쪽이 더 이상하다
      expect(at(now.add(const Duration(minutes: 3))).isNewAt(now), isTrue);
    });
  });
}
