import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple 로그인 결과.
/// 서버에는 [identityToken]을 넘겨 검증받는다(카카오의 액세스 토큰에 대응).
class AppleLoginResult {
  const AppleLoginResult({
    required this.identityToken,
    required this.userIdentifier,
    this.email,
    this.fullName,
  });

  /// 서버가 Apple 공개키로 검증할 JWT
  final String identityToken;

  /// Apple이 앱마다 부여하는 고유 사용자 ID
  final String userIdentifier;

  /// 최초 로그인 시에만 제공. 사용자가 가리기를 선택하면 릴레이 주소가 온다.
  final String? email;

  /// 최초 로그인 시에만 제공
  final String? fullName;
}

/// 사용자가 로그인 시트를 닫는 등 스스로 취소한 경우
class AppleLoginCancelled implements Exception {
  const AppleLoginCancelled();
}

class AppleAuthService {
  const AppleAuthService();

  /// 취소 시 [AppleLoginCancelled]를 던진다.
  ///
  /// 이름·이메일은 **최초 로그인 1회만** 내려오므로, 서버가 이때 저장해야 한다.
  /// 재로그인 시에는 null이 오는 것이 정상.
  Future<AppleLoginResult> login() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        throw StateError('Apple identityToken을 받지 못했습니다.');
      }
      final given = credential.givenName;
      final family = credential.familyName;
      final name = [family, given].whereType<String>().join();
      return AppleLoginResult(
        identityToken: identityToken,
        userIdentifier: credential.userIdentifier ?? '',
        email: credential.email,
        fullName: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AppleLoginCancelled();
      }
      rethrow;
    }
  }
}
