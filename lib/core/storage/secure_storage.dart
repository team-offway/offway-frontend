import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

/// JWT 액세스/리프레시 토큰을 iOS Keychain에 보관한다.
///
/// 예전에는 게스트 ID(`guest_id`)도 여기 두고 X-Guest-Id 헤더로 실었다.
/// 소유를 서버가 JWT로 판단하면서(core #320) 지웠다 — 옛 설치에 남은
/// 키는 읽는 곳이 없어 그냥 묵는다.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  /// 로그아웃·탈퇴 뒤에 쓴다 — 토큰을 비운다
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
