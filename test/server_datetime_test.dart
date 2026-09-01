import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/date_format.dart';

/// 서버 시각(오프셋 없는 KST)을 어느 기기에서나 같은 순간으로 읽는지 고정한다.
void main() {
  test('오프셋이 없으면 KST로 읽는다', () {
    final t = parseServerDateTime('2026-09-01T14:03:22')!;
    expect(t.isAtSameMomentAs(DateTime.utc(2026, 9, 1, 5, 3, 22)), isTrue);
  });

  test('오프셋이 있으면 그대로 둔다', () {
    final t = parseServerDateTime('2026-09-01T14:03:22+00:00')!;
    expect(t.isAtSameMomentAs(DateTime.utc(2026, 9, 1, 14, 3, 22)), isTrue);
    final z = parseServerDateTime('2026-09-01T05:03:22Z')!;
    expect(z.isAtSameMomentAs(DateTime.utc(2026, 9, 1, 5, 3, 22)), isTrue);
  });

  test('날짜만 와도 KST 자정으로 읽는다', () {
    // '2026-05-08'의 '-'를 오프셋으로 오인하면 안 된다
    final t = parseServerDateTime('2026-05-08')!;
    expect(t.isAtSameMomentAs(DateTime.utc(2026, 5, 7, 15)), isTrue);
  });

  test('없거나 못 읽으면 null', () {
    expect(parseServerDateTime(null), isNull);
    expect(parseServerDateTime(''), isNull);
    expect(parseServerDateTime('언제'), isNull);
  });
}
