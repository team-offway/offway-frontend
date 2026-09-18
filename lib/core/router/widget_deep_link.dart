import 'app_router.dart';

/// 위젯을 눌러 앱이 열렸을 때 갈 화면 — `offway://` 스킴(#297).
///
/// 위젯(네이티브 `TripWidgetSnapshot.deepLink`)이 만드는 주소는 셋이다.
///
/// | 주소 | 뜻 | 화면 |
/// |---|---|---|
/// | `offway://course/{savedId}` | 보여주던 여행 | 코스 상세 |
/// | `offway://course/{savedId}?day=2` | 여행 중 — 2일차를 보여주던 중 | 코스 상세, 2일차 탭 |
/// | `offway://wizard` | 예정 여행 없음 | 코스 만들기(위저드 처음부터) |
/// | `offway://home` | 로그인 전 | 홈 — 스플래시가 로그인 여부로 첫 화면을 정한다 |
///
/// 우리 스킴이 아니면 null — 공유 링크(`shareToken`)는 따로 푼다.
/// 모르는 주소면 홈이다 — 위젯을 눌렀는데 아무 일도 없는 것보다 낫다
String? widgetDeepLinkRoute(Uri uri) {
  if (uri.scheme != widgetDeepLinkScheme) return null;
  switch (uri.host) {
    case 'course':
      // pathSegments 는 디코드된 값이다 — '/' 가 든 id 를 그대로 끼우면 경로가
      // 두 칸이 되어 `/my-courses/:savedId` 에 안 맞는다. 한 칸으로 되돌린다
      final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
      // 출발 전에는 안 붙는다(며칠째가 없다) — 그때는 첫날로 연다.
      // 1 미만은 버린다. 코스 길이를 넘는 값은 화면이 첫날로 되돌린다
      final day = int.tryParse(uri.queryParameters['day'] ?? '');
      return id.isEmpty
          ? AppRoutes.home
          : AppRoutes.savedCoursePath(
              Uri.encodeComponent(id),
              day: day != null && day >= 1 ? day : null,
            );
    case 'wizard':
      return AppRoutes.wizardDateGate;
    default:
      return AppRoutes.home;
  }
}

/// `Info.plist` `CFBundleURLSchemes` 와 같아야 한다
const widgetDeepLinkScheme = 'offway';
