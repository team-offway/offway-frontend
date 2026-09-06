import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/date_format.dart';

final updatePromptSnoozeProvider = Provider<UpdatePromptSnoozeStorage>(
  (ref) => UpdatePromptSnoozeStorage(const FlutterSecureStorage()),
);

/// '나중에'를 누른 날 — 그날 하루만 업데이트 모달을 접어 둔다.
///
/// "다녀오셨나요?"의 미룸([TripOutcomeSnoozeStorage])과 같은 규칙이다.
/// 스토어 **버전별**로 담는다 — 1.0.4를 미뤘는데 1.0.5가 올라오면 그건 새
/// 얘기라 다시 묻는다. 토큰과 같은 Keychain을 쓰되 로그아웃이 지우는
/// 토큰 저장소와는 섞지 않는다.
class UpdatePromptSnoozeStorage {
  UpdatePromptSnoozeStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _prefix = 'update_prompt_snoozed_';

  String _key(String version) => '$_prefix$version';

  Future<bool> isSnoozedToday(String version, DateTime today) async {
    final saved = await _storage.read(key: _key(version));
    return saved != null && saved == isoDate(today);
  }

  Future<void> snooze(String version, DateTime today) =>
      _storage.write(key: _key(version), value: isoDate(today));
}
