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

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

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
