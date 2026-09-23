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

  /// Keychain 값을 한 번 읽어 **들고 있는다**.
  ///
  /// 앞의 구조는 요청마다 Keychain 을 다시 열었다 — 인터셉터가 매 요청
  /// [accessToken] 을 읽고, 기기 등록·사용자 조회도 따로 읽는다. 값은 로그인·
  /// 재발급·로그아웃에서만 바뀌고 그 셋이 전부 이 클래스를 거치므로, 여기서
  /// 갈아 끼우면 밖에서 낡은 값을 볼 일이 없다.
  ///
  /// `Future` 를 그대로 든다 — 동시에 온 첫 읽기들이 Keychain 조회 한 번을
  /// 나눠 쓴다. 읽기가 실패하면 비워 다음에 다시 읽는다. 실패한 `Future` 를
  /// 들고 있으면 그 뒤 모든 요청이 같은 실패를 되풀이한다
  Future<String?>? _access;
  Future<String?>? _refresh;

  Future<String?> get accessToken {
    if (_access case final cached?) return cached;
    late final Future<String?> read;
    // 실패했을 때 **아직 이 읽기가 캐시일 때만** 비운다 — 그 사이 저장·
    // 로그아웃이 새 값을 넣었으면 그것을 지우면 안 된다
    read = _read(
      _accessTokenKey,
      forget: () {
        if (identical(_access, read)) _access = null;
      },
    );
    return _access = read;
  }

  Future<String?> get refreshToken {
    if (_refresh case final cached?) return cached;
    late final Future<String?> read;
    read = _read(
      _refreshTokenKey,
      forget: () {
        if (identical(_refresh, read)) _refresh = null;
      },
    );
    return _refresh = read;
  }

  Future<String?> _read(String key, {required void Function() forget}) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      forget();
      rethrow;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    // Keychain 에 쓴 **뒤에** 갈아 끼운다 — 쓰기가 실패하면 들고 있는 값과
    // 저장된 값이 어긋난다
    await _storage.write(key: _accessTokenKey, value: accessToken);
    _access = Future<String?>.value(accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      _refresh = Future<String?>.value(refreshToken);
    }
  }

  /// 로그아웃·탈퇴 뒤에 쓴다 — 토큰을 비운다
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    _access = Future<String?>.value(null);
    await _storage.delete(key: _refreshTokenKey);
    _refresh = Future<String?>.value(null);
  }
}
