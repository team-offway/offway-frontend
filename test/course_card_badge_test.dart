import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';

/// 내 코스 카드의 상태 뱃지 규칙.
///
/// 날짜가 지났다고 무조건 '여행완료'가 아니다 — 모달에서 다녀왔다고 답해
/// 연차가 차감된([visited]) 여행만 완료고, 무시했거나 안 갔다고 한 여행은
/// '미방문'이다.
void main() {
  final today = DateTime(2026, 8, 24);
  final pastStart = DateTime(2026, 7, 20);
  final pastEnd = DateTime(2026, 7, 22);

  test('끝난 여행이라도 차감 전이면 미방문이다', () {
    final badge = courseCardBadge(
      pastStart,
      pastEnd,
      visited: false,
      today: today,
    );
    expect(badge?.label, '미방문');
    // 시안(1207-39864): 글자 Label/Alternative · 배경 Fill/Normal —
    // 다른 뱃지처럼 글자색 8%가 아니다
    expect(badge?.fg, AppColors.labelAlternative);
    expect(badge?.bg, AppColors.fillNormal);
  });

  test('모달에서 다녀왔다고 답해 차감된 여행만 여행완료다', () {
    final badge = courseCardBadge(
      pastStart,
      pastEnd,
      visited: true,
      today: today,
    );
    expect(badge?.label, '여행완료');
  });

  test('미방문이던 코스도 날짜를 미래로 옮기면 다시 D-day다', () {
    final badge = courseCardBadge(
      DateTime(2026, 8, 29),
      DateTime(2026, 8, 31),
      visited: false,
      today: today,
    );
    expect(badge?.label, 'D-5');
  });

  test('여행 당일은 D-DAY다', () {
    final badge = courseCardBadge(
      today,
      DateTime(2026, 8, 26),
      visited: false,
      today: today,
    );
    expect(badge?.label, 'D-DAY');
  });

  test('날짜가 없으면 뱃지도 없다', () {
    expect(courseCardBadge(null, null, visited: false, today: today), isNull);
  });
}
