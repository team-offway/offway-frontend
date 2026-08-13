/// 앱 전역 설정.
///
/// 빌드 시 `--dart-define`으로 값을 주입할 수 있다.
/// 예: flutter run --dart-define=API_BASE_URL=https://api.offway.com
abstract final class AppConfig {
  /// 백엔드(Spring) API 베이스 URL.
  /// iOS 시뮬레이터에서는 localhost가 Mac 호스트를 가리킨다.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// 코스 공유 링크가 열리는 보기 전용 웹 주소 (`web/share`를 Vercel에 배포).
  ///
  /// 서버가 정한 경로는 `/c/{shareToken}`.
  /// 배포 환경을 옮기면 `--dart-define=SHARE_BASE_URL=...`로 바꾼다.
  static const String shareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://offway.cloud',
  );

  /// 개인정보처리방침 — 공유 웹페이지와 같은 배포에 함께 올라간다
  /// (`web/share/privacy.html`). 앱 심사에서 요구하는 필수 링크다.
  static String get privacyPolicyUrl => '$_webBase/privacy';

  /// 이용약관 — 방침과 같은 배포에 함께 올라간다 (`web/share/terms.html`).
  /// 로그인 화면에서 "가입 시 이용약관에 동의하게 됩니다"라고 안내하므로
  /// 실제로 열람할 수 있어야 한다.
  static String get termsOfServiceUrl => '$_webBase/terms';

  static String get _webBase => shareBaseUrl.replaceAll(RegExp(r'/+$'), '');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// 임시 Basic 인증 계정 (백엔드 #122 게이트).
  ///
  /// 서버가 외부 API 쿼터(TMAP 일 50건)를 지키려고 전체 요청을 Basic 인증으로
  /// 막아뒀다. 소셜 로그인(#93)이 붙으면 서버와 함께 걷어낸다.
  ///
  /// 레포가 public이므로 실제 값은 절대 커밋하지 말고 --dart-define으로만 주입:
  /// flutter run --dart-define=BASIC_AUTH_USER=... --dart-define=BASIC_AUTH_PASS=...
  static const String basicAuthUser = String.fromEnvironment('BASIC_AUTH_USER');
  static const String basicAuthPass = String.fromEnvironment('BASIC_AUTH_PASS');

  /// 네이버 지도 Client ID.
  /// 번들 ID(com.nth.offway)로 사용이 제한되는 공개 식별자라 기본값 커밋 가능.
  /// Client Secret은 서버 전용이므로 앱/레포에 절대 넣지 말 것.
  static const String naverMapClientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: 'qqdpbn2yp9',
  );

  /// 카카오 네이티브 앱 키.
  /// 앱에 내장되는 공개 키로 번들 ID로 사용이 제한된다.
  /// REST API 키·Admin 키는 서버 전용이므로 앱/레포에 넣지 말 것.
  ///
  /// ⚠️ iOS URL scheme(`kakao<키>`)도 같은 값을 써야 카카오톡에서 앱으로 복귀한다.
  /// scheme은 `ios/Flutter/AppKeys.xcconfig`의 `KAKAO_NATIVE_APP_KEY`를 참조하므로,
  /// 키를 바꿀 때는 **그 파일과 아래 기본값(또는 --dart-define)을 함께** 변경할 것.
  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '4994e03bad5d46f2e22f2386053619db',
  );
}
