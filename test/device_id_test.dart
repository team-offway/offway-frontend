import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/storage/device_id.dart';

/// 이 기기를 가리키는 값 — 서버가 같은 사용자의 기기를 가른다(core #587).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// Keychain 대역 — 실제 저장소 대신 맵에 담는다
  late Map<String, String> stored;
  late int writes;

  setUp(() {
    stored = {};
    writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final key = args['key'] as String?;
          return switch (call.method) {
            'read' => stored[key],
            'write' => () {
              writes++;
              stored[key!] = args['value'] as String;
              return null;
            }(),
            'delete' => stored.remove(key),
            'readAll' => stored,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('처음 부르면 만들어 저장하고, 그 뒤로는 같은 값이다', () async {
    final storage = DeviceIdStorage(const FlutterSecureStorage());
    final first = await storage.get();
    final second = await storage.get();

    expect(first, isNotEmpty);
    expect(second, first, reason: '기기 id 가 바뀌면 서버가 한 기기를 둘로 센다');
  });

  test('다시 만든 저장소도 같은 값을 읽는다 — 앱을 껐다 켜도 이어진다', () async {
    final first = await DeviceIdStorage(const FlutterSecureStorage()).get();
    final again = await DeviceIdStorage(const FlutterSecureStorage()).get();

    expect(again, first);
    expect(writes, 1, reason: '이미 있는데 다시 저장했다');
  });

  test('동시에 불러도 하나만 만든다', () async {
    // 앱이 뜨자마자 푸시 등록과 잠금화면이 같이 부른다 — 각자 만들면
    // 같은 실행 안에서도 id 가 갈린다
    final storage = DeviceIdStorage(const FlutterSecureStorage());
    final results = await Future.wait([
      storage.get(),
      storage.get(),
      storage.get(),
    ]);

    expect(results.toSet(), hasLength(1));
    expect(writes, 1);
  });

  test('32자리 hex 다 — 로그·URL 어디에 들어가도 그대로', () {
    final id = DeviceIdStorage.newId();

    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    // 매번 다른 값이어야 기기를 가른다
    expect(DeviceIdStorage.newId(), isNot(id));
  });
}
