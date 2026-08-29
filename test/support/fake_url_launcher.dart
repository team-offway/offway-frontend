import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// 링크를 실제로 열지 않고 **무엇을 어떤 방식으로 열려 했는지**만 기록한다.
///
/// 네이티브 채널의 인자 이름(`useSafariVC` 등)은 플러그인 버전에 따라 바뀐다.
/// 우리가 고정하고 싶은 것은 그 규약이 아니라 "앱 안에서 여는가"이므로
/// 플랫폼 인터페이스를 갈아끼워 [PreferredLaunchMode]를 직접 본다.
///
/// ```dart
/// final launcher = FakeUrlLauncher.install();
/// ...
/// expect(launcher.lastMode, PreferredLaunchMode.inAppBrowserView);
/// ```
class FakeUrlLauncher extends UrlLauncherPlatform {
  FakeUrlLauncher._();

  /// [UrlLauncherPlatform.instance]를 가짜로 바꾸고, 테스트가 끝나면 되돌린다.
  ///
  /// 되돌리지 않으면 같은 파일의 다음 테스트가 앞 테스트의 기록을 본다.
  static FakeUrlLauncher install() {
    final previous = UrlLauncherPlatform.instance;
    final fake = FakeUrlLauncher._();
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    return fake;
  }

  /// 마지막으로 열려 한 주소 — 한 번도 안 열었으면 null
  String? lastUrl;

  /// 마지막으로 쓴 열기 방식 — 앱 안이면 [PreferredLaunchMode.inAppBrowserView]
  PreferredLaunchMode? lastMode;

  /// 몇 번 열렸는지 — 한 번 눌러 두 번 열리는 일을 잡는다
  int launchCount = 0;

  /// 열기가 실패하는 상황(주소는 성했지만 열 수 없는 경우)을 흉내 낸다
  bool succeeds = true;

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    lastMode = options.mode;
    launchCount++;
    return succeeds;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}
