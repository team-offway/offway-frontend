import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/trip_activity/data/trip_activity_service.dart';
import 'package:offway/features/trip_activity/domain/trip_countdown.dart';

/// 잠금화면을 여닫는 다리 — 네이티브와 주고받는 약속을 고정한다.
///
/// **UI는 Swift가 그린다.** 여기서 보는 것은 "무엇을 어떤 이름으로
/// 넘기는가"뿐이다. 이름이나 키가 어긋나면 실기기에서만 드러나므로
/// 여기서 못 박는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late TripActivityService service;

  /// 네이티브 대신 받아 적는 대역
  void stub({Object? Function(MethodCall call)? answer}) {
    calls = [];
    const channel = MethodChannel(TripActivityService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return answer?.call(call);
        });
    // 테스트는 macOS VM 에서 돈다 — iOS 인 척해야 채널까지 간다
    service = TripActivityService(channel: channel, isSupportedPlatform: true);
  }

  final trip = TripCountdown(
    courseId: '7',
    regionName: '정선군',
    startDate: DateTime(2026, 9, 23),
    endDate: DateTime(2026, 9, 25),
    durationLabel: '2박 3일',
  );

  test('띄울 때 화면이 쓸 값을 모두 넘긴다', () async {
    stub();
    await service.start(trip, now: DateTime(2026, 9, 20));

    expect(calls.single.method, 'start');
    final args = (calls.single.arguments as Map).cast<String, Object?>();
    expect(args['courseId'], '7');
    expect(args['regionName'], '정선군');
    // 문구는 앱이 만들어 넘긴다 — 네이티브가 한국어를 조립하지 않게
    expect(args['headline'], '정선군 여행 D-3');
    expect(args['rangeLabel'], '2026.9.23 - 9.25');
    expect(args['daysUntil'], 3);
    // 자정에 네이티브가 스스로 다시 셀 수 있게 날짜도 넘긴다
    expect(args['startDate'], isNotNull);
    expect(args['endDate'], isNotNull);
  });

  test('여행 중이면 며칠째인지 넘긴다', () async {
    stub();
    await service.start(trip, now: DateTime(2026, 9, 24));

    final args = (calls.single.arguments as Map).cast<String, Object?>();
    expect(args['headline'], '정선군 여행 2일차');
  });

  test('내릴 때는 end 를 부른다', () async {
    stub();
    await service.end();

    expect(calls.single.method, 'end');
  });

  test('가능 여부는 네이티브가 답한다', () async {
    stub(answer: (_) => true);
    expect(await service.isAvailable(), isTrue);
    expect(calls.single.method, 'isAvailable');
  });

  test('네이티브가 없는 빌드에서도 깨지지 않는다', () async {
    // 채널을 아예 걸지 않는다 — MissingPluginException 이 난다
    const channel = MethodChannel(TripActivityService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final s = TripActivityService(channel: channel, isSupportedPlatform: true);

    // 잠금화면이 안 뜨는 것뿐이다 — 앱이 하던 일을 막지 않는다
    expect(await s.isAvailable(), isFalse);
    await s.start(trip);
    await s.end();
  });

  test('네이티브가 실패해도 삼킨다', () async {
    stub(
      answer: (_) => throw PlatformException(code: 'ERR', message: '못 띄웠다'),
    );

    expect(await service.isAvailable(), isFalse);
    // 던지지 않는다
    await service.start(trip);
    await service.end();
  });
}
