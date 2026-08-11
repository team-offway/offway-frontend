import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

/// 코스 링크를 카카오톡으로 보낸다.
///
/// 카카오톡이 깔려 있으면 앱을 바로 열고, 없으면 브라우저의 카카오톡 공유
/// 페이지로 넘긴다 — 어느 쪽이든 받는 사람에게는 같은 링크가 간다.
abstract final class KakaoShare {
  /// 공유가 실제로 열렸는지. 실패하면 화면이 그 사실을 알린다.
  static Future<bool> sendCourse({
    required String title,
    required String description,
    required String linkUrl,
    required String shareToken,
    String? imageUrl,
  }) async {
    final template = FeedTemplate(
      content: Content(
        title: title,
        description: description,
        // 이미지가 없으면 카카오가 회색 자리를 그린다 — 대표 이미지가 있으면 넣는다
        imageUrl: Uri.parse(imageUrl ?? ''),
        link: Link(
          webUrl: Uri.parse(linkUrl),
          mobileWebUrl: Uri.parse(linkUrl),
        ),
      ),
      buttons: [
        Button(
          title: '코스 보기',
          link: Link(
            webUrl: Uri.parse(linkUrl),
            mobileWebUrl: Uri.parse(linkUrl),
          ),
        ),
      ],
    );

    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        // 카카오톡이 있으면 이 한 번으로 앱까지 띄워 준다
        await ShareClient.instance.shareDefault(template: template);
        return true;
      }

      // 카카오톡이 없으면 웹 공유 창으로 — 로그인 후 같은 링크를 보낼 수 있다
      final uri = await WebSharerClient.instance.makeDefaultUrl(
        template: template,
      );
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
