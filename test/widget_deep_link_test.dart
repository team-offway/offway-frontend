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
