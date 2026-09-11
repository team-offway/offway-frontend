import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final courseTooltipStorageProvider = Provider<CourseTooltipStorage>(
  (ref) => CourseTooltipStorage(const FlutterSecureStorage()),
);

/// 코스 화면의 안내 툴팁을 이미 보여 줬는지 기억한다 (시안 1505:55696·56078).
///
/// 툴팁은 **무엇을 할 수 있는지 한 번 알려 주는 자리**다. 볼 때마다 다시 뜨면
/// 그때부터는 잔소리가 된다. 그래서 "할 일을 다 했다"고 볼 수 있는 순간에
/// 여기에 남기고, 다음부터는 띄우지 않는다.
///
/// 화면마다 역할이 다르다(시안 메모).
///
/// | 화면 | 툴팁 | 끝나는 시점 |
/// |---|---|---|
/// | 코스 확정(저장 전) | 코스를 공유해보세요 | 닫기(X)를 누름 |
/// | 내 코스(저장 후 첫 진입) | 눌러서 자세히 보기 | 장소 상세로 들어감 |
/// | 내 코스(재진입) | 코스를 공유해보세요 | 닫기(X)를 누름 |
///
/// **코스별로 나눠 담는다.** 새로 담은 코스는 처음 보는 코스이므로 안내가
/// 다시 필요하다 — 앱 전체에 한 번만 띄우면 두 번째 코스부터는 상세로
/// 들어가는 길을 모른 채 목록만 본다.
///
/// 스크롤로 잠시 감추는 것은 여기 남기지 않는다. 그건 "읽는 동안 비켜 준다"는
/// 뜻이라, 다시 맨 위로 오면 나와도 된다.
///
/// 토큰과 같은 Keychain을 쓰되 [TokenStorage]와 섞지 않는다 — 로그아웃이
/// 토큰을 지울 때 이것까지 지우면 안내가 처음부터 다시 시작된다.
class CourseTooltipStorage {
  CourseTooltipStorage(this._storage);

  final FlutterSecureStorage _storage;

  /// 코스 확정 화면의 공유 안내를 닫았는가 — 코스를 가리지 않는 **앱 전체**
  /// 값이다. 추천 코스는 볼 때마다 다른 코스라 코스별로 두면 매번 뜬다
  static const _sharePromptClosedKey = 'course_share_tip_closed';

  /// 내 코스에서 '눌러서 자세히 보기'를 이미 본 코스들
  static const _detailHintPrefix = 'saved_course_detail_hint_';

  String _detailHintKey(String savedId) => '$_detailHintPrefix$savedId';

  /// 코스 확정에서 공유 안내를 닫은 적이 있는가
  Future<bool> isSharePromptClosed() async =>
      await _storage.read(key: _sharePromptClosedKey) != null;

  /// 공유 안내를 닫았다고 남긴다 — 다시 띄우지 않는다
  Future<void> closeSharePrompt() =>
      _storage.write(key: _sharePromptClosedKey, value: 'closed');

  /// 이 코스에서 '눌러서 자세히 보기'를 이미 보여 줬는가
  Future<bool> isDetailHintDone(String savedId) async =>
      await _storage.read(key: _detailHintKey(savedId)) != null;

  /// 상세로 들어갔다 — 이 코스에는 더 안내하지 않는다
  Future<void> markDetailHintDone(String savedId) =>
      _storage.write(key: _detailHintKey(savedId), value: 'done');
}
