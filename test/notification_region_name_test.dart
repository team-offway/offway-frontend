import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/notification/domain/app_notification.dart';

/// 알림이 **어떤 여행인지** 말하는지 고정한다 (core #359).
///
/// 코스를 여럿 담아 둔 사람에게 "여행, 다녀오셨나요?"는 어느 것인지 알 수
/// 없다. 특히 TRIP_AFTER는 "연차를 기록해 달라"는 요청이라, 어느 여행인지
/// 모르면 눌러서 확인하기 전까지 판단할 수 없다.
void main() {
  AppNotification notification(NotificationType type, {String? regionName}) =>
      AppNotification(
        id: 1,
        type: type,
        read: false,
        courseId: 58,
        regionName: regionName,
      );

  group('지역명이 오면', () {
    test('여행 다음 날 알림이 어느 여행인지 밝힌다', () {
      final body = notification(
        NotificationType.tripAfter,
        regionName: '정선',
      ).body;

      expect(body, contains("'정선 여행'"));
      expect(body, contains('다녀오셨나요?'));
    });

    test('여행 전날 알림도 마찬가지다', () {
      final body = notification(
        NotificationType.tripTomorrow,
        regionName: '정선',
      ).body;

      expect(body, contains("'정선 여행'"));
    });

    test('자치구는 그대로 쓴다', () {
      // 서버가 군·시만 뗀다 — '동구'에서 한 글자를 더 떼면 지명이 아니게
      // 된다(core #359). 앱은 받은 이름을 다듬지 않는다
      expect(
        notification(NotificationType.tripAfter, regionName: '동구').body,
        contains("'동구 여행'"),
      );
    });
  });

  group('지역명이 없으면', () {
    test('코스가 지워졌으면 지역명 없는 문구로 되돌린다', () {
      // 알림은 코스가 사라져도 남는다 — 서버가 null로 준다
      final body = notification(NotificationType.tripAfter).body;

      expect(body, isNot(contains("''")));
      expect(body, contains('여행, 다녀오셨나요?'));
    });

    test('빈 문자열도 없는 것으로 친다', () {
      // 그대로 쓰면 "' 여행' 다녀오셨나요?"가 된다
      expect(
        notification(NotificationType.tripAfter, regionName: '  ').body,
        contains('여행, 다녀오셨나요?'),
      );
    });

    test('모르는 종류는 지역명이 있어도 기본 문구다', () {
      expect(
        notification(NotificationType.unknown, regionName: '정선').body,
        '새로운 소식이 도착했어요.',
      );
    });
  });

  group('응답 파싱', () {
    test('regionName을 읽는다', () {
      final item = AppNotification.fromJson(const {
        'id': 12,
        'type': 'TRIP_AFTER',
        'courseId': 58,
        'regionName': '정선',
        'read': false,
      });

      expect(item.regionName, '정선');
      expect(item.body, contains("'정선 여행'"));
    });

    test('키가 없는 옛 응답도 받는다', () {
      // 서버 배포 전 앱이 먼저 나가도 목록이 깨지지 않는다
      final item = AppNotification.fromJson(const {
        'id': 12,
        'type': 'TRIP_AFTER',
        'read': false,
      });

      expect(item.regionName, isNull);
      expect(item.body, contains('여행, 다녀오셨나요?'));
    });
  });
}
