/// 앱 버전 — `1.0.3` 처럼 점으로 나뉜 숫자열. 빌드 번호(`+30`)는 안 본다.
///
/// 스토어가 주는 버전과 이 앱의 버전을 **숫자 자리마다** 비교한다.
/// 문자열로 비교하면 `1.10.0`이 `1.9.0`보다 작아진다.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  /// 못 읽으면 null — 그때는 업데이트를 묻지 않는다(틀린 안내보다 조용한 게 낫다)
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim().split('+').first;
    if (text.isEmpty) return null;
    final parts = <int>[];
    for (final piece in text.split('.')) {
      final n = int.tryParse(piece);
      if (n == null || n < 0) return null;
      parts.add(n);
    }
    return AppVersion(parts);
  }

  final List<int> parts;

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => parts.join('.');
}

/// 스토어에 올라온 더 새 버전 — 업데이트 모달이 가리키는 것.
class AppUpdate {
  const AppUpdate({required this.storeVersion, required this.storeUrl});

  /// 스토어 버전 문자열(`1.0.4`). 스누즈 키로도 쓴다 — 버전이 바뀌면 다시 묻는다
  final String storeVersion;

  /// App Store 앱 페이지
  final String storeUrl;
}

/// 지금 앱과 스토어 버전을 견줘 업데이트가 있는지.
///
/// 어느 쪽이든 못 읽으면 null — TestFlight 빌드가 스토어보다 새롭거나 아직
/// 스토어에 없는 동안(`resultCount` 0)에도 null이다.
AppUpdate? decideUpdate({
  required String? currentVersion,
  required String? storeVersion,
  required String? storeUrl,
}) {
  final current = AppVersion.tryParse(currentVersion);
  final store = AppVersion.tryParse(storeVersion);
  if (current == null || store == null || storeUrl == null) return null;
  if (!(store > current)) return null;
  return AppUpdate(storeVersion: store.toString(), storeUrl: storeUrl);
}
