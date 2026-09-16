import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 스플래시가 끝나면 갈 곳 — 앱이 꺼진 채 링크(위젯·공유)로 열렸을 때.
///
/// 앱이 꺼져 있다 링크로 열리면 첫 화면은 스플래시다. 그 위에 목적지를
/// 바로 올리면 1.2초 뒤 스플래시가 `go(next)` 로 스택을 통째로 갈아 치우며
/// 지운다 — 위젯을 눌렀는데 홈에 떨어진다. 그래서 스플래시가 떠 있는 동안
/// 온 링크는 여기 맡겨 두고, 스플래시가 다음 화면으로 간 **뒤에** 연다.
typedef PendingDeepLink = ({String route, bool replace});

class PendingDeepLinkNotifier extends Notifier<PendingDeepLink?> {
  @override
  PendingDeepLink? build() => null;

  /// [replace] 가 참이면 스택을 그 화면으로 바꾸고(`go`), 아니면 위에 올린다(`push`)
  void set(String route, {required bool replace}) =>
      state = (route: route, replace: replace);

  /// 꺼내 간다 — 한 번만 쓴다
  PendingDeepLink? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, PendingDeepLink?>(
      PendingDeepLinkNotifier.new,
    );
