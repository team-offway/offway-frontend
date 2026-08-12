import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 구글 로그인 창구. 테스트는 이 프로바이더를 갈아 끼워 실제 SDK를 피한다.
final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => const GoogleAuthService(),
);

/// 사용자가 계정 선택 창을 닫는 등 스스로 취소한 경우
class GoogleLoginCancelled implements Exception {
  const GoogleLoginCancelled();
}

/// 구글 로그인 결과 — 서버로 넘길 ID 토큰과 프로필.
typedef GoogleLoginResult = ({
  String idToken,
  String email,
  String? displayName,
  String userId,
});

/// 구글 계정으로 로그인한다.
///
/// 클라이언트 ID는 `GoogleService-Info.plist`(iOS)에서 읽으므로 코드에 두지
/// 않는다. 그 파일은 레포가 public이라 커밋하지 않는다.
///
/// 테스트에서는 [login]만 갈아끼운 하위 클래스를 프로바이더로 넣어
/// 실제 계정 선택 창이 뜨지 않게 한다.
class GoogleAuthService {
  const GoogleAuthService();

  static final _signIn = GoogleSignIn.instance;

  /// 한 번만 하면 되는 초기화 — 여러 번 불러도 안전하게 한 번만 돈다
  static Future<void>? _ready;
  static Future<void> _ensureInitialized() => _ready ??= _signIn.initialize();

  /// 서버로 넘길 **ID 토큰**과 프로필을 반환한다.
  ///
  /// 카카오는 액세스 토큰을 주고 서버가 프로필을 조회하지만, 구글은 ID 토큰
  /// 안에 이메일·이름이 서명된 채로 들어 있어 서버가 검증만 하면 된다.
  /// 취소 시 [GoogleLoginCancelled]를 던진다.
  Future<GoogleLoginResult> login() async {
    await _ensureInitialized();
    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      // 토큰이 없으면 서버가 사용자를 확인할 방법이 없다 — 성공으로 볼 수 없다
      if (idToken == null || idToken.isEmpty) {
        throw Exception('구글이 ID 토큰을 주지 않았습니다');
      }
      return (
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        userId: account.id,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleLoginCancelled();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();
    await _signIn.signOut();
  }
}
