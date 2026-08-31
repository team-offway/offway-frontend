import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/notification/application/push_presenter.dart';
import 'package:offway/features/notification/domain/app_notification.dart';

/// 푸시가 목록 셀과 **같은 말을 하고 같은 곳으로 보내는지**, 그리고 배너가
/// **두 번 뜨지 않는지** 고정한다.
///
/// 서버가 문구를 실어 보내면(core #358) 앱이 켜져 있어도 시스템이 배너를
/// 그린다. 그때 앱이 또 그리면 같은 알림이 두 번 뜬다. 문구 없이 오는
/// 메시지에만 앱이 나서고, 그 문구는 목록 셀과 같아야 한다.
void main() {
  group('문구', () {
    test('지역명이 없으면 목록 셀과 배너가 같은 문구를 쓴다', () {
      // 배너는 아직 지역명 없이 온다(core #358) — 그때 두 문구가 갈리면
      // 사용자는 같은 알림을 둘로 읽는다
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

  group('도착 알리기', () {
    /// 배너 표시는 네이티브 채널이라 테스트에서 돌지 않는다. 그 앞에서
    /// 도착을 알리는지만 본다 — 배너가 못 떠도 앱 안에는 흔적이 남아야 한다
    RemoteMessage messageOf(String type) => RemoteMessage(data: {'type': type});

    /// 서버가 문구를 실어 보낸 메시지 (core #358)
    RemoteMessage withBanner(String type) => RemoteMessage(
      data: {'type': type},
      notification: const RemoteNotification(title: '알림', body: '문구'),
    );

    testWidgets('푸시가 오면 배지·목록 갱신을 알린다', (tester) async {
      var arrived = 0;
      final presenter = PushPresenter()..onArrived = () => arrived++;

      await presenter.show(messageOf('TRIP_TOMORROW'));

      expect(arrived, 1, reason: '배너만 띄우고 끝내면 앱에 돌아왔을 때 티가 안 난다');
    });

    testWidgets('배너를 못 띄워도 도착은 알린다', (tester) async {
      // initialize를 부르지 않아 표시가 막힌 상태 — 알림이 온 것은 사실이다
      var arrived = 0;
      final presenter = PushPresenter()..onArrived = () => arrived++;

      await presenter.show(messageOf('UNKNOWN_KIND'));

      expect(arrived, 1);
    });

    testWidgets('서버가 문구를 실어 보내도 배지는 켠다', (tester) async {
      // 배너는 시스템이 그리지만, 종 배지와 목록은 앱 몫이다
      var arrived = 0;
      final presenter = PushPresenter()..onArrived = () => arrived++;

      await presenter.show(withBanner('TRIP_AFTER'));

      expect(arrived, 1);
    });
  });

  group('배너 중복', () {
    test('서버가 문구를 실었으면 앱은 그리지 않는다', () {
      // 앱이 켜져 있어도 시스템이 배너를 띄운다 — 여기서 또 그리면
      // 같은 알림이 두 번 뜬다 (core #358 이후)
      expect(
        PushPresenter.needsLocalBanner(
          RemoteMessage(
            data: const {'type': 'TRIP_TOMORROW'},
            notification: const RemoteNotification(title: '알림', body: '문구'),
          ),
        ),
        isFalse,
        reason: '시스템 배너와 겹쳐 두 번 뜬다',
      );
    });

    test('문구 없이 오면 앱이 대신 그린다', () {
      // 옛 서버나 다른 발송 경로 — 그때까지 배너를 잃지 않는다
      expect(
        PushPresenter.needsLocalBanner(
          RemoteMessage(data: const {'type': 'TRIP_TOMORROW'}),
        ),
        isTrue,
      );
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

  group('배너로 들어오면 읽음 처리', () {
    test('서버가 실어 준 알림 id로 읽음 처리한다', () {
      // core #367이 payload에 넣기 시작했다 — 배너를 눌러 확인한 알림이
      // 계속 안 읽음으로 남지 않는다
      int? read;
      var arrived = 0;
      final presenter = PushPresenter();
      presenter.onRead = (id) => read = id;
      presenter.onArrived = () => arrived++;

      presenter.openFromPayload({
        'type': 'TRIP_AFTER',
        'courseId': '58',
        'notificationId': '12',
      });

      expect(read, 12);
      // 읽음 처리가 배지를 맞추므로 도착 알림까지 겹쳐 부르지 않는다
      expect(arrived, 0);
    });

    test('옛 서버는 그 키가 없어 도착만 알린다', () {
      // 키가 없어도 깨지지 않는다 — 목록에서 눌러 읽게 둔다
      int? read;
      var arrived = 0;
      final presenter = PushPresenter();
      presenter.onRead = (id) => read = id;
      presenter.onArrived = () => arrived++;

      presenter.openFromPayload({'type': 'TRIP_AFTER', 'courseId': '58'});

      expect(read, isNull);
      expect(arrived, 1);
    });

    test('갈 곳이 있으면 이동도 한다', () {
      String? route;
      final presenter = PushPresenter();
      presenter.onOpenRoute = (r) => route = r;

      presenter.openFromPayload({
        'type': 'TRIP_TOMORROW',
        'courseId': '7',
        'notificationId': '3',
      });

      expect(route, AppRoutes.savedCoursePath('7'));
    });
  });
}
