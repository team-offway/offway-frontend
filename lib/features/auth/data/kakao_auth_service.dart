import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// 사용자가 로그인 창을 닫는 등 스스로 취소한 경우
class KakaoLoginCancelled implements Exception {
  const KakaoLoginCancelled();
}

class KakaoAuthService {
  const KakaoAuthService();

  /// 카카오톡이 설치돼 있으면 앱으로, 없으면 카카오계정(웹)으로 로그인한다.
  ///
  /// 서버로 넘길 **액세스 토큰만** 반환한다. 프로필은 서버가 이 토큰으로 조회하므로
  /// 앱에서 따로 가져오지 않는다 — 조회 실패가 이미 성공한 로그인을 되돌리는 것을 막고,
  /// 사용자 식별자를 앱 로그에 남기지 않기 위함.
  /// 취소 시 [KakaoLoginCancelled]를 던진다.
  Future<String> login() async {
    final token = await _requestToken();
    return token.accessToken;
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
