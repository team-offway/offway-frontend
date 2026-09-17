import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_locator.dart';

/// 출발 좌표는 **한 주행에 한 번만** 잡는다(#317).
///
/// 후보 지역 진입과 코스 생성이 각각 부르고 '새로운 추천 받기' 마다 또 부르는데,
/// 그때마다 권한 확인과 측위를 새로 돌아 사용자를 몇 초씩 기다리게 했다.
class _FakeLocator extends OriginLocator {
  _FakeLocator({
    required super.now,
    this.result = const Origin(lat: 37.4, lng: 127.1, isFallback: false),
  });

  /// 실제 측위가 일어난 횟수
  int fixes = 0;

  /// 다음 측위가 돌려줄 값 — 테스트가 갈아 끼운다
  Origin result;

  @override
  Future<Origin> locate() async {
    fixes++;
    return result;
  }
}

void main() {
  var clock = DateTime(2026, 9, 17, 10);
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 9, 17, 10));

  test('연달아 부르면 한 번만 잡는다', () async {
    final locator = _FakeLocator(now: now);

    final first = await locator.resolve();
    final second = await locator.resolve();
    final third = await locator.resolve();

    expect(locator.fixes, 1, reason: '같은 자리에서 측위를 되풀이했다');
    expect(second.lat, first.lat);
    expect(third.lng, first.lng);
  });

  test('시간이 지나면 다시 잡는다', () async {
    final locator = _FakeLocator(now: now);
    await locator.resolve();

    // 아직 유효한 동안
    clock = clock.add(OriginLocator.cacheTtl - const Duration(seconds: 1));
    await locator.resolve();
    expect(locator.fixes, 1);

    // 지나면 새로 잡는다 — 멀리 이동한 뒤 다시 추천받는 경우다
    clock = clock.add(const Duration(seconds: 2));
    await locator.resolve();
    expect(locator.fixes, 2);
  });

  test('폴백은 붙들지 않는다 — 다음에 다시 잡는다', () async {
    // 권한을 방금 켰거나 신호가 잠깐 끊겼던 사용자가 5분 동안 서울에서
    // 출발하게 되면 안 된다
    final locator = _FakeLocator(
      now: now,
      result: const Origin(lat: 37.5665, lng: 126.978, isFallback: true),
    );

    final first = await locator.resolve();
    final second = await locator.resolve();

    expect(first.isFallback, isTrue);
    expect(second.isFallback, isTrue);
    expect(locator.fixes, 2, reason: '폴백을 캐시해 다시 잡지 않았다');
  });

  test('폴백 뒤에 잡히면 그때부터 붙든다', () async {
    final locator = _FakeLocator(
      now: now,
      result: const Origin(lat: 37.5665, lng: 126.978, isFallback: true),
    );
    await locator.resolve();
    expect(locator.fixes, 1);

    // 권한을 켰다 — 이번엔 실제 좌표가 잡힌다
    locator.result = const Origin(lat: 35.1, lng: 129.0, isFallback: false);
    final fixed = await locator.resolve();
    expect(locator.fixes, 2);
    expect(fixed.isFallback, isFalse);

    // 그 뒤로는 다시 잡지 않는다
    final cached = await locator.resolve();
    expect(locator.fixes, 2);
    expect(cached.lat, 35.1);
  });
}
