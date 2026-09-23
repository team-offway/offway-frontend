import 'package:flutter/foundation.dart';

/// 개발 중에만 찍는 로그. **release 빌드에서는 아무것도 하지 않는다.**
///
/// `debugPrint` 는 이름과 달리 release 에서도 기기 로그(syslog)로 나간다.
/// 예외 문자열(`$e`)에는 요청 주소·응답 일부가 담길 수 있어, 실사용자 기기에
/// 남기지 않는다.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
