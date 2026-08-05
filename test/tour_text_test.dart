import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/tour_text.dart';

void main() {
  test('br 태그는 줄바꿈으로 바뀐다', () {
    expect(
      cleanTourApiText('[일반열람실]<br>- 07:00~22:00<br />- 평일 09:00~19:00'),
      '[일반열람실]\n- 07:00~22:00\n- 평일 09:00~19:00',
    );
  });

  test('나머지 태그는 사라지고 엔티티는 원래 문자로 돌아온다', () {
    expect(
      cleanTourApiText('<b>산책로</b> A &amp; B&nbsp;코스'),
      '산책로 A & B 코스',
    );
  });

  test('태그가 없는 문장은 그대로 둔다', () {
    expect(cleanTourApiText('매주 월요일'), '매주 월요일');
    expect(cleanTourApiText(null), null);
  });
}
