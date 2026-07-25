import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// 카카오 로그인 결과.
/// 서버 인증 도메인 구축 전이라 앱에서 카카오 인증까지만 수행하고,
/// 이 값을 서버에 넘겨 우리 JWT로 교환하는 단계는 이후에 붙인다.
class KakaoLoginResult {
  const KakaoLoginResult({
    required this.accessToken,
    required this.userId,
    this.nickname,
    this.profileImageUrl,
  });

  /// 서버로 넘겨 검증받을 카카오 액세스 토큰
  final String accessToken;

  /// 카카오 회원번호 — 동의항목과 무관하게 항상 제공되는 사용자 식별자
  final int userId;

  /// 닉네임·프로필 이미지는 동의 여부에 따라 없을 수 있다
  final String? nickname;
  final String? profileImageUrl;
}

/// 사용자가 로그인 창을 닫는 등 스스로 취소한 경우
class KakaoLoginCancelled implements Exception {
  const KakaoLoginCancelled();
}

class KakaoAuthService {
  const KakaoAuthService();

  /// 카카오톡이 설치돼 있으면 앱으로, 없으면 카카오계정(웹)으로 로그인한다.
  /// 취소 시 [KakaoLoginCancelled]를 던진다.
  Future<KakaoLoginResult> login() async {
    final token = await _requestToken();
    final user = await UserApi.instance.me();
    return KakaoLoginResult(
      accessToken: token.accessToken,
      userId: user.id,
      nickname: user.kakaoAccount?.profile?.nickname,
      profileImageUrl: user.kakaoAccount?.profile?.profileImageUrl,
    );
  }

  Future<OAuthToken> _requestToken() async {
    final talkInstalled = await isKakaoTalkInstalled();
    if (talkInstalled) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } on PlatformException catch (e) {
        // 카카오톡 로그인 화면에서 사용자가 취소하면 앱 전환이 중단된다
        if (e.code == 'CANCELED') throw const KakaoLoginCancelled();
        // 카카오톡은 있으나 계정 미로그인 등으로 실패하면 웹 로그인으로 대체
        debugPrint('카카오톡 로그인 실패, 웹 로그인으로 전환: $e');
      }
    }
    try {
      return await UserApi.instance.loginWithKakaoAccount();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const KakaoLoginCancelled();
      rethrow;
    }
  }

  Future<void> logout() => UserApi.instance.logout();
}
