import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/notification/domain/app_notification.dart';

/// 푸시 배너가 목록 셀과 **같은 말을 하고 같은 곳으로 보내는지** 고정한다.
///
/// 서버는 data-only 메시지를 보낸다(core #270) — 문구를 서버에 굳히지 않으려는
/// 것이고, 그래서 배너를 앱이 직접 그린다. 두 곳에 문구를 따로 적으면 한쪽만
/// 고쳐져 배너와 목록이 다른 말을 한다.
void main() {
  group('문구', () {
    test('목록 셀과 배너가 같은 문구를 쓴다', () {
      for (final type in NotificationType.values) {
        final item = AppNotification(id: 1, type: type, read: false);
        expect(
          notificationBody(type),
          item.body,
          reason: '$type 의 배너와 셀이 갈리면 안 된다',
        );
      }
    });

    test('모르는 종류에도 빈 배너를 띄우지 않는다', () {
      // 서버가 종류를 늘려도 앱을 업데이트하지 않은 사용자에게 알림이 간다
      expect(notificationBody(NotificationType.unknown), isNotEmpty);
    });
  });

  group('누르면 갈 곳', () {
    test('여행 다음 날 알림은 내 연차로 보낸다', () {
      // 그 화면이 "다녀오셨나요?" 모달을 띄운다
      expect(
        notificationDestination(NotificationType.tripAfter, null),
        AppRoutes.myLeaveFromNotification,
      );
    });

    test('여행 전날 알림은 그 코스로 보낸다', () {
      expect(
        notificationDestination(NotificationType.tripTomorrow, 7),
        AppRoutes.savedCoursePath('7'),
      );
    });

    test('코스가 없으면 이동하지 않는다', () {
      // 알림은 코스가 지워져도 남는다 — 갈 곳 없는 이동을 시키지 않는다
      expect(
        notificationDestination(NotificationType.tripTomorrow, null),
        isNull,
      );
    });

    test('모르는 종류는 이동하지 않는다', () {
      expect(notificationDestination(NotificationType.unknown, 7), isNull);
    });

    test('목록 셀도 같은 규칙을 쓴다', () {
      const item = AppNotification(
        id: 1,
        type: NotificationType.tripTomorrow,
        read: false,
        courseId: 3,
      );
      expect(item.destination, AppRoutes.savedCoursePath('3'));
    });
  });

  group('서버 payload', () {
    // 서버는 data 값을 전부 String으로 싣는다(FcmPushSender.payload)
    int? courseIdOf(Map<String, dynamic> data) =>
        int.tryParse(data['courseId']?.toString() ?? '');

    test('문자열로 온 courseId를 읽는다', () {
      expect(courseIdOf({'type': 'TRIP_TOMORROW', 'courseId': '42'}), 42);
    });

    test('courseId가 없는 알림도 있다', () {
      expect(courseIdOf({'type': 'TRIP_AFTER'}), isNull);
    });

    test('type을 모르면 unknown으로 받는다', () {
      // 파싱에서 터지면 새 알림 하나 때문에 배너가 통째로 안 뜬다
      expect(NotificationType.parse('SOMETHING_NEW'), NotificationType.unknown);
      expect(NotificationType.parse(null), NotificationType.unknown);
    });
  });
}
