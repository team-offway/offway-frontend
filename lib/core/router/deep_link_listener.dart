import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';

/// 공유 링크로 앱이 열렸을 때 그 코스 화면으로 보낸다.
///
/// 카카오톡 '앱으로 보기'는 앱 스킴에 `shareToken`을 실어 보낸다
/// (`kakao{앱키}://kakaolink?shareToken=...`). 이 값이 없으면 그냥 홈에 머문다.
///
/// 앱이 꺼져 있다 열린 경우(첫 링크)와 떠 있는 상태에서 열린 경우를 모두 받는다.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    // 앱이 꺼져 있다 링크로 열린 경우
    try {
      final initial = await _appLinks.getInitialLink();
      // 기다리는 사이 화면이 사라졌으면 여기서 끝낸다 — dispose가 이미 지나가
      // 아래에서 구독을 만들면 아무도 취소해 주지 않는다
      if (!mounted) return;
      if (initial != null) _handle(initial);
    } on Exception {
      // 링크를 못 읽어도 앱은 홈에서 정상 동작한다
      if (!mounted) return;
    }
    _subscription = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    final token = uri.queryParameters['shareToken'];
    if (token == null || token.isEmpty) return;
    // context로는 못 찾는다 — MaterialApp.router의 builder는 라우터 바깥이라
    // 그 안에서 GoRouter.of(context)를 부르면 예외가 난다. 라우터를 직접 잡는다
    final router = ref.read(appRouterProvider);
    // 라우터가 준비된 뒤 옮겨야 첫 프레임과 부딪히지 않는다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      router.push(AppRoutes.sharedCoursePath(token));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
