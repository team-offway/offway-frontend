import '../../../core/config/app_config.dart';
import '../data/kakao_share.dart' show SharedCourseKind;

/// 코스 공유 링크.
///
/// 서버가 주는 `shareToken`으로 만든다. 받은 사람은 계정이 없어도
/// `GET /api/v1/public/courses/{shareToken}`으로 볼 수 있다.
/// **토큰이 있다고 공개된 것은 아니다** — 링크를 넘겨야 비로소 남이 본다.
abstract final class ShareLink {
  /// 보기 전용 웹 주소.
  ///
  /// 어디서 공유했느냐에 따라 열리는 화면이 다르다 — 추천코스는 안내 문구를,
  /// 내 코스는 여행 날짜와 연차를 보여준다.
  ///
  /// 주입한 주소 끝에 슬래시가 붙어 있어도 `//r/`가 되지 않게 다듬는다.
  static String of(String shareToken, {required SharedCourseKind kind}) {
    final base = AppConfig.shareBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = switch (kind) {
      SharedCourseKind.recommend => 'r',
      SharedCourseKind.saved => 'm',
    };
    return '$base/$path/$shareToken';
  }
}
