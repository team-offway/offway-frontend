import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/date_format.dart';

final tripOutcomeSnoozeProvider = Provider<TripOutcomeSnoozeStorage>(
  (ref) => TripOutcomeSnoozeStorage(const FlutterSecureStorage()),
);

/// "나중에 할게요"를 누른 날 — 그날 하루만 모달을 접어 둔다.
///
/// 시안 정책: *나중에 할게요 → 당일 재노출 X / 다음 날 홈 진입 → 다시 노출*.
/// '안 갔어요'·'다녀왔어요'는 서버가 영구히 기억하므로(`trip-outcome`)
/// 여기 남길 게 없다. **미룸만 로컬 몫이다** — 서버에 '오늘은 안 볼래'라는
/// 상태가 없고, 있어야 할 이유도 없다(기기마다 다른 이야기다).
///
/// 코스별로 나눠 담는다. 여행 A를 미뤘다고 여행 B까지 접히면,
/// 다음 날 두 개가 한꺼번에 밀려온다.
///
/// 토큰과 같은 Keychain을 쓰되 [TokenStorage]와 섞지 않는다 — 로그아웃이
/// 토큰을 지울 때 이것까지 지우면, 다시 들어오자마자 미뤄둔 모달이 뜬다.
class TripOutcomeSnoozeStorage {
  TripOutcomeSnoozeStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _prefix = 'trip_outcome_snoozed_';

  String _key(int courseId) => '$_prefix$courseId';

  /// [courseId]를 오늘 이미 미뤘는지
  Future<bool> isSnoozedToday(int courseId, DateTime today) async {
    final saved = await _storage.read(key: _key(courseId));
    return saved != null && saved == isoDate(today);
  }

  /// 오늘은 묻지 않는다고 남긴다
  Future<void> snooze(int courseId, DateTime today) =>
      _storage.write(key: _key(courseId), value: isoDate(today));

  /// 답을 받았으면 지운다 — 서버가 기억하므로 로컬에 남길 이유가 없다
  Future<void> clear(int courseId) => _storage.delete(key: _key(courseId));
}
