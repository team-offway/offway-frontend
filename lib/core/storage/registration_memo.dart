import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 기기 토큰(FCM) — `POST /devices`
final deviceRegistrationMemoProvider = Provider<RegistrationMemo>(
  (ref) =>
      RegistrationMemo(const FlutterSecureStorage(), key: 'device_registered'),
);

/// 잠금화면 push-to-start 토큰 — `PUT /live-activities/push-to-start`
final pushToStartMemoProvider = Provider<RegistrationMemo>(
  (ref) => RegistrationMemo(
    const FlutterSecureStorage(),
    key: 'push_to_start_registered',
  ),
);

/// "이 값을 서버에 올린 적이 있다"를 기억한다.
///
/// 앱을 켤 때마다 같은 토큰을 다시 올리고 있었다 — 기기 등록과 push-to-start
/// 둘 다. 토큰은 재설치·복원·갱신에서만 바뀌고, 그때는 값이 달라 자연히
/// 다시 올라간다. 같은 값이면 건너뛴다.
///
/// **[maxAge] 가 지나면 같은 값이라도 다시 올린다.** 서버가 오래된 등록을
/// 정리하더라도 이레 안에 되살아나게 — 건너뛰기가 등록을 영영 잃게 하면 안 된다.
///
/// 로그아웃에서 [forget] 한다 — 다음 사람은 같은 기기 토큰을 자기 계정으로
/// 다시 올려야 한다.
///
/// Keychain 에 둔다 — 앱이 쓰는 유일한 로컬 저장소라 의존성을 늘리지 않는다.
/// 재설치 뒤에도 남지만, 그때는 토큰 자체가 새것이라 문제가 되지 않는다
class RegistrationMemo {
  RegistrationMemo(
    this._storage, {
    required String key,
    DateTime Function()? now,
  }) : _key = key,
       _now = now ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final String _key;
  final DateTime Function() _now;

  static const maxAge = Duration(days: 7);

  /// [value] 를 [maxAge] 안에 올린 적이 있는가
  Future<bool> isRegistered(String value) async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return false;
    // 값 뒤에 시각을 붙여 둔다 — 토큰에 `|` 가 올 일은 없지만 뒤에서 자른다
    final sep = raw.lastIndexOf('|');
    if (sep < 0 || raw.substring(0, sep) != value) return false;
    final at = DateTime.tryParse(raw.substring(sep + 1));
    if (at == null) return false;
    return _now().difference(at) < maxAge;
  }

  Future<void> remember(String value) =>
      _storage.write(key: _key, value: '$value|${_now().toIso8601String()}');

  Future<void> forget() => _storage.delete(key: _key);
}
