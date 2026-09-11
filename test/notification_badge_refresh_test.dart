import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/dio_client.dart';
import 'package:offway/features/notification/application/notification_provider.dart';

/// 종 아이콘의 파란 점은 **여러 번 다시 묻는다**.
///
/// 앱 실행 중 한 번만 물으면 이런 경우에 점이 안 켜진다.
/// - 백그라운드에 둔 사이 알림이 쌓였을 때 (푸시 배너를 못 봤거나 알림을 껐다)
/// - 로그인 직후 — 앞 계정 기준 상태가 남는다
/// - 조회가 한 번 실패했을 때 — 다시 시도할 길이 없었다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith(_Stub stub) {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'))
      ..httpClientAdapter = stub;
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('다시 물으면 새 알림이 반영된다', () async {
    final stub = _Stub(unread: 0);
    final c = containerWith(stub);
    c.listen(hasUnreadNotificationsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.read(hasUnreadNotificationsProvider), isFalse);

    // 백그라운드에 둔 사이 알림이 쌓였다
    stub.unread = 2;
    await c.read(hasUnreadNotificationsProvider.notifier).refresh();

    expect(c.read(hasUnreadNotificationsProvider), isTrue);
  });

  test('한 번 실패해도 다음에 다시 묻는다', () async {
    final stub = _Stub(unread: 3, fail: true);
    final c = containerWith(stub);
    c.listen(hasUnreadNotificationsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // 못 읽었으니 꺼진 채다
    expect(c.read(hasUnreadNotificationsProvider), isFalse);

    stub.fail = false;
    await c.read(hasUnreadNotificationsProvider.notifier).refresh();

    expect(c.read(hasUnreadNotificationsProvider), isTrue);
  });

  test('겹쳐 불러도 왕복은 한 번이다', () async {
    // 화면이 여럿 겹치거나 복귀가 연달아 와도 서버를 두들기지 않는다
    final stub = _Stub(unread: 1, delay: const Duration(milliseconds: 80));
    final c = containerWith(stub);
    c.listen(hasUnreadNotificationsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final before = stub.calls;

    final notifier = c.read(hasUnreadNotificationsProvider.notifier);
    await Future.wait([notifier.refresh(), notifier.refresh()]);

    expect(stub.calls - before, 1);
  });
}

class _Stub implements HttpClientAdapter {
  _Stub({required this.unread, this.fail = false, this.delay = Duration.zero});

  int unread;
  bool fail;
  Duration delay;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!options.path.contains('notifications')) {
      return ResponseBody.fromString('{}', 200);
    }
    calls += 1;
    if (fail) {
      return ResponseBody.fromString(
        jsonEncode({'status': 500, 'code': 'ERR', 'detail': '실패'}),
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'status': 200,
        'code': 'OK',
        'data': {'notifications': [], 'unreadCount': unread},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
