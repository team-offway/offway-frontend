import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';

/// 서버가 내려준 주소를 앱이 열어도 되는지 판정한다.
///
/// 서버도 저장할 때 https를 강제하지만(core #350), 웹뷰에 주소를 넘기는 것은
/// 앱이다. 한 겹만 믿으면 서버의 다른 경로(옛 데이터·다른 API·어드민)로 들어온
/// 값이 그대로 통과한다.
///
/// - `http`는 암호화되지 않은 채로 오간다
/// - `javascript:`·`data:` 같은 스킴은 웹뷰에서 열 것이 아니다
/// - `https:///path`처럼 스킴만 맞고 갈 곳이 없는 값도 막는다
///
/// 열 수 없는 주소면 null을 준다 — 부르는 쪽이 버튼째 감추거나 안내한다.
Uri? safeExternalUri(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  // scheme은 파싱 단계에서 이미 소문자로 정규화된다
  if (uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

/// 외부 페이지를 앱 안에서 띄운다.
///
/// iOS는 SFSafariViewController로 열려 상단에 주소가 그대로 보이고, 닫으면
/// 부르던 화면으로 돌아온다 — 페이지 하나를 보려고 앱을 떠날 이유가 없다.
///
/// 열지 못하면 [failureMessage]를 주의(삼각형) 토스트로 알리고 false를 준다.
/// 못 여는 길이 셋인데 화면에서는 다 같은 일이라 한 곳에서 처리한다.
///
/// 1. 주소가 https가 아니거나 깨졌다 ([safeExternalUri]가 걸러낸다)
/// 2. `launchUrl`이 false를 준다 (열 앱이 없는 등)
/// 3. `launchUrl`이 던진다 — 플러그인은 실패를 예외로도 알린다. 이걸 놓치면
///    아무 일도 안 일어난 것처럼 보여, 사용자는 버튼이 고장난 줄 안다
Future<bool> openExternalLink(
  BuildContext context,
  String? url, {
  String failureMessage = '페이지를 열지 못했어요.',
}) async {
  final uri = safeExternalUri(url);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } on Exception {
      // 왜 못 열었는지는 사용자가 할 수 있는 일을 바꾸지 않는다 —
      // 어느 쪽이든 "다시 눌러 보세요"가 답이다
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    showAppToast(context, failureMessage, kind: AppToastKind.cautionary);
  }
  return opened;
}
