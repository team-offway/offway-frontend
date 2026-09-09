import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 지금 깔린 앱의 버전 — `1.0.4 (32)`.
///
/// 마이 페이지 맨 아래에 적는다. 테스터가 "어느 빌드에서 그랬다"를 말할 때
/// TestFlight를 열어 보지 않아도 되게 하는 자리다. 스토어 버전과 견주는
/// 업데이트 안내(`availableUpdateProvider`)와 같은 값을 읽는다.
///
/// 못 읽으면(플러그인 없는 환경) 빈 값 — 화면은 그 줄을 지운다.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersion(info.version, info.buildNumber);
}, retry: (retryCount, error) => null);

/// `1.0.4` + `32` → `1.0.4 (32)`. 빌드번호가 없으면 버전만
String formatAppVersion(String version, String buildNumber) {
  final v = version.trim();
  final b = buildNumber.trim();
  if (v.isEmpty) return '';
  return b.isEmpty ? v : '$v ($b)';
}
