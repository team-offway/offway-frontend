import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final shareTokenStoreProvider = Provider<ShareTokenStore>(
  (ref) => const ShareTokenStore(),
);

/// 코스별 공유 토큰 보관소.
///
/// 서버는 **저장(`POST /courses`) 응답에만** 토큰을 싣는다 — 목록·상세를 다시
/// 불러도 `shareToken`은 null이다. 그래서 저장하는 순간 받아 기기에 적어두고,
/// 나중에 공유할 때 꺼내 쓴다.
///
/// 앱을 지우면 사라지므로 예전 코스는 링크를 만들 수 없다.
/// TODO(server): 상세·목록 응답에도 토큰이 실리면 이 저장소는 지운다.
class ShareTokenStore {
  const ShareTokenStore();

  static const _key = 'course_share_tokens';
  static const _storage = FlutterSecureStorage();

  Future<Map<String, String>> _all() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    // 저장된 값이 깨졌거나 형태가 다르면 없는 셈 친다 —
    // 공유만 못 할 뿐 앱은 돌아가야 한다
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  Future<String?> tokenOf(String courseId) async => (await _all())[courseId];

  Future<void> save(String courseId, String shareToken) async {
    final all = await _all()
      ..[courseId] = shareToken;
    await _storage.write(key: _key, value: jsonEncode(all));
  }
}
