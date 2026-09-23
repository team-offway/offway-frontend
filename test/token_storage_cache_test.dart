import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/storage/secure_storage.dart';

/// 토큰은 Keychain 을 한 번만 읽고 들고 있는다 — 요청마다 다시 열지 않는다.
///
/// 앞의 구조는 인터셉터가 매 요청 Keychain 을 열었다. 값은 로그인·재발급·
/// 로그아웃에서만 바뀌고 셋 다 이 클래스를 거친다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> stored;
  late int reads;
  late bool failNextRead;

  setUp(() {
    stored = {};
    reads = 0;
    failNextRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              reads++;
              if (failNextRead) {
                failNextRead = false;
                throw PlatformException(code: 'keychain');
              }
              return stored[key];
            case 'write':
              stored[key!] = args['value'] as String;
              return null;
            case 'delete':
              stored.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('두 번 읽어도 Keychain 은 한 번만 연다', () async {
    stored['access_token'] = 'a1';
    final storage = TokenStorage(const FlutterSecureStorage());
    expect(await storage.accessToken, 'a1');
    expect(await storage.accessToken, 'a1');
    expect(reads, 1);
  });

  test('동시에 온 첫 읽기들은 한 번의 조회를 나눠 쓴다', () async {
    // 앱을 켜면 홈·사용자·기기 등록이 같이 나간다 — 셋이 각각 열 이유가 없다
    stored['access_token'] = 'a1';
    final storage = TokenStorage(const FlutterSecureStorage());
    final all = await Future.wait([
      storage.accessToken,
      storage.accessToken,
      storage.accessToken,
    ]);
    expect(all, ['a1', 'a1', 'a1']);
    expect(reads, 1);
  });

  test('저장하면 다시 읽지 않고 새 값을 준다 — Keychain 에도 쓴다', () async {
    final storage = TokenStorage(const FlutterSecureStorage());
    expect(await storage.accessToken, isNull);
    await storage.saveTokens(accessToken: 'a2', refreshToken: 'r2');
    expect(await storage.accessToken, 'a2');
    expect(await storage.refreshToken, 'r2');
    expect(reads, 1, reason: '저장 뒤 읽기는 Keychain 을 열지 않는다');
    expect(stored, {'access_token': 'a2', 'refresh_token': 'r2'});
  });

  test('지우면 null 이고 다시 읽지 않는다', () async {
    stored['access_token'] = 'a1';
    stored['refresh_token'] = 'r1';
    final storage = TokenStorage(const FlutterSecureStorage());
    await storage.accessToken;
    await storage.clear();
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
    expect(reads, 1);
    expect(stored, isEmpty);
  });

  test('읽기가 실패하면 그 실패를 들고 있지 않는다 — 다음에 다시 읽는다', () async {
    // 실패한 Future 를 들고 있으면 그 뒤 모든 요청이 같은 실패를 되풀이한다
    stored['access_token'] = 'a1';
    failNextRead = true;
    final storage = TokenStorage(const FlutterSecureStorage());
    await expectLater(storage.accessToken, throwsA(isA<PlatformException>()));
    expect(await storage.accessToken, 'a1');
    expect(reads, 2);
  });

  test('늦게 실패한 옛 읽기가 그 사이 저장한 새 값을 지우지 않는다', () async {
    stored['access_token'] = 'old';
    failNextRead = true;
    final storage = TokenStorage(const FlutterSecureStorage());
    // 실패할 읽기에 기대를 **먼저** 건다 — 저장을 기다리는 사이 실패가 난다
    final first = expectLater(
      storage.accessToken,
      throwsA(isA<PlatformException>()),
    );
    await storage.saveTokens(accessToken: 'new');
    await first;
    expect(await storage.accessToken, 'new');
    expect(reads, 1, reason: '새 값을 들고 있으니 다시 읽지 않는다');
  });
}
