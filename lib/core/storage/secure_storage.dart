import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

/// JWT 액세스/리프레시 토큰과 게스트 ID를 iOS Keychain에 보관한다.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _guestIdKey = 'guest_id';

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  /// 비회원 식별자 (서버 X-Guest-Id 헤더, #34).
  ///
  /// 연차·저장한 코스가 이 값에 묶이므로 잃어버리면 데이터를 다시 못 찾는다.
  /// Keychain은 앱을 지웠다 깔아도 남아 게스트 데이터가 이어진다.
  Future<String?> get guestId => _storage.read(key: _guestIdKey);

  Future<void> saveGuestId(String id) =>
      _storage.write(key: _guestIdKey, value: id);

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

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// 탈퇴 뒤에 쓴다 — 토큰과 함께 게스트 ID까지 비운다.
  ///
  /// [clear]가 게스트 ID를 남기는 것은 로그아웃 때 맞는 동작이다(같은 기기의
  /// 비회원 데이터를 이어 쓴다). 탈퇴는 반대다 — 남겨두면 서버에서 지운
  /// 데이터를 옛 게스트 ID로 다시 만들어 탈퇴한 흔적이 따라온다.
  Future<void> clearAll() async {
    await clear();
    await _storage.delete(key: _guestIdKey);
  }
}
