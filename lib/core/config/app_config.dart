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
}
