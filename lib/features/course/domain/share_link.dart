import '../../../core/config/app_config.dart';

/// 코스 공유 링크.
///
/// 서버가 저장 응답에 주는 `shareToken`으로 만든다. 받은 사람은 계정이 없어도
/// `GET /api/v1/public/courses/{shareToken}`으로 볼 수 있다.
/// **토큰이 있다고 공개된 것은 아니다** — 링크를 넘겨야 비로소 남이 본다.
abstract final class ShareLink {
  /// 보기 전용 웹 주소 — 서버 스펙이 정한 경로는 `/c/{shareToken}`
  static String of(String shareToken) =>
      '${AppConfig.shareBaseUrl}/c/$shareToken';
}
