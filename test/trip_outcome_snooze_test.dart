import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/trip_outcome_snooze_storage.dart';

/// '나중에 할게요' 정책 — 당일만 접고 다음 날 다시 묻는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TripOutcomeSnoozeStorage snooze;

  setUp(() {
    // Keychain은 테스트에서 못 쓴다 — 플러그인이 제공하는 인메모리 대체를 쓴다
    FlutterSecureStorage.setMockInitialValues({});
    snooze = TripOutcomeSnoozeStorage(const FlutterSecureStorage());
  });

  final day1 = DateTime(2026, 7, 23);
  final day2 = DateTime(2026, 7, 24);

  test('미루기 전에는 접히지 않는다', () async {
    expect(await snooze.isSnoozedToday(12, day1), isFalse);
  });

  test('미룬 당일에는 접힌다', () async {
    await snooze.snooze(12, day1);
    expect(await snooze.isSnoozedToday(12, day1), isTrue);
  });

  test('다음 날에는 다시 묻는다', () async {
    // 시안: '나중에 할게요 → 당일 재노출 X / 다음 날 홈 진입 → 다시 노출'
    await snooze.snooze(12, day1);
    expect(await snooze.isSnoozedToday(12, day2), isFalse);
  });

  test('코스마다 따로 기억한다', () async {
    // 여행 A를 미뤘다고 B까지 접히면, 다음 날 둘이 한꺼번에 밀려온다
    await snooze.snooze(12, day1);
    expect(await snooze.isSnoozedToday(99, day1), isFalse);
  });

  test('답을 받으면 기록을 지운다', () async {
    await snooze.snooze(12, day1);
    await snooze.clear(12);
    expect(await snooze.isSnoozedToday(12, day1), isFalse);
  });
}
