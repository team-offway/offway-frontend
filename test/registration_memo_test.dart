import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/storage/registration_memo.dart';

/// "이 값을 서버에 올린 적이 있다"를 기억한다 — 앱을 켤 때마다 같은 기기
/// 토큰을 다시 올리지 않게.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> stored;
  late bool failRead;
  var now = DateTime(2026, 9, 24, 12);

  setUp(() {
    stored = {};
    failRead = false;
    now = DateTime(2026, 9, 24, 12);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final key = args['key'] as String?;
          return switch (call.method) {
            'read' =>
              failRead
                  ? throw PlatformException(code: 'keychain')
                  : stored[key],
            'write' => () {
              stored[key!] = args['value'] as String;
              return null;
            }(),
            'delete' => stored.remove(key),
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  RegistrationMemo memo([String key = 'device_registered']) =>
      RegistrationMemo(const FlutterSecureStorage(), key: key, now: () => now);

  test('올린 적이 없으면 거짓', () async {
    expect(await memo().isRegistered('t1'), isFalse);
  });

  test('올린 값은 참, 다른 값은 거짓 — 토큰이 바뀌면 자연히 다시 올라간다', () async {
    final m = memo();
    await m.remember('t1');
    expect(await m.isRegistered('t1'), isTrue);
    expect(await m.isRegistered('t2'), isFalse);
  });

  test('이레가 지나면 같은 값이라도 다시 올린다 — 서버가 정리해도 되살아나게', () async {
    final m = memo();
    await m.remember('t1');
    now = now.add(const Duration(days: 6));
    expect(await m.isRegistered('t1'), isTrue);
    now = now.add(const Duration(days: 2));
    expect(await m.isRegistered('t1'), isFalse);
  });

  test('잊으면 다시 올린다 — 로그아웃', () async {
    final m = memo();
    await m.remember('t1');
    await m.forget();
    expect(await m.isRegistered('t1'), isFalse);
  });

  test('키가 다르면 서로 모른다 — 기기 등록과 push-to-start 는 다른 표다', () async {
    await memo('device_registered').remember('t1');
    expect(await memo('push_to_start_registered').isRegistered('t1'), isFalse);
  });

  test('저장된 값이 깨져 있으면 거짓 — 다시 올리는 쪽이 늘 안전하다', () async {
    stored['device_registered'] = 'no-separator';
    expect(await memo().isRegistered('no-separator'), isFalse);
    stored['device_registered'] = 't1|not-a-date';
    expect(await memo().isRegistered('t1'), isFalse);
  });

  test('시계를 되돌려 적어 둔 시각이 미래면 믿지 않는다', () async {
    final m = memo();
    await m.remember('t1');
    now = now.subtract(const Duration(days: 3));
    expect(await m.isRegistered('t1'), isFalse);
  });

  test('기억을 못 읽으면 거짓 — 등록까지 건너뛰면 안 된다', () async {
    final m = memo();
    await m.remember('t1');
    failRead = true;
    expect(await m.isRegistered('t1'), isFalse);
  });

  test('시각은 UTC 로 적는다 — 시간대를 바꿔도 만료가 틀어지지 않게', () async {
    await memo().remember('t1');
    expect(stored['device_registered'], endsWith('Z'));
  });
}
