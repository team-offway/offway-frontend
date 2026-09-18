import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/router/widget_deep_link.dart';

/// 위젯을 눌러 앱이 열렸을 때 — `offway://` 주소를 화면으로 푼다(#297).
///
/// 네이티브 `TripWidgetSnapshot.deepLink` 가 만드는 세 주소와 1:1 이다.
/// 어긋나면 위젯을 눌렀는데 홈에 떨어지고, 실기기에서만 드러난다.
void main() {
  test('보여주던 여행이 있으면 그 코스 상세로', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('offway://course/122')),
      AppRoutes.savedCoursePath('122'),
    );
  });

  test('id 는 경로 한 칸이다 — 슬래시가 들어 있어도 두 칸으로 쪼개지 않는다', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('offway://course/a%2Fb')),
      '/my-courses/a%2Fb',
    );
  });

  test('여행 중이면 보여주던 일자로 연다 — 방금 본 날을 다시 찾지 않게', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('offway://course/122?day=2')),
      AppRoutes.savedCoursePath('122', day: 2),
    );
  });

  test('일자가 없으면 첫날이다 — 출발 전에는 며칠째가 없다', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('offway://course/122')),
      isNot(contains('day=')),
    );
  });

  test('일자가 1 보다 작거나 숫자가 아니면 버린다', () {
    for (final bad in ['0', '-1', 'two', '']) {
      expect(
        widgetDeepLinkRoute(Uri.parse('offway://course/122?day=$bad')),
        AppRoutes.savedCoursePath('122'),
        reason: 'day=$bad 는 첫날로 떨어져야 한다',
      );
    }
  });

  test('예정 여행이 없으면 코스 만들기로', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('offway://wizard')),
      AppRoutes.wizardDateGate,
    );
  });

  test('로그인 전이거나 모르는 주소면 홈 — 눌렀는데 아무 일도 없는 것보다 낫다', () {
    expect(widgetDeepLinkRoute(Uri.parse('offway://home')), AppRoutes.home);
    expect(widgetDeepLinkRoute(Uri.parse('offway://nowhere')), AppRoutes.home);
    expect(widgetDeepLinkRoute(Uri.parse('offway://course')), AppRoutes.home);
  });

  test('우리 스킴이 아니면 관여하지 않는다 — 공유 링크는 따로 푼다', () {
    expect(
      widgetDeepLinkRoute(Uri.parse('kakaoabc://kakaolink?shareToken=x')),
      isNull,
    );
    expect(widgetDeepLinkRoute(Uri.parse('https://offway.cloud/m/x')), isNull);
  });
}
