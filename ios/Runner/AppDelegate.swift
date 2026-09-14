import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // 앱을 보고 있는 동안 온 알림도 배너로 띄운다.
    // 이 델리게이트가 없으면 flutter_local_notifications가 그린 알림이
    // 포그라운드에서 조용히 삼켜져, "푸시가 안 온다"로 보인다
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // 잠금화면·다이나믹 아일랜드 다리 — Flutter 가 값만 넘기고 화면은
    // Widget Extension(SwiftUI)이 그린다.
    //
    // **super 뒤에 붙인다.** window·rootViewController 를 만드는 것이
    // FlutterAppDelegate 의 super 라, 그 앞에서는 window 가 nil 이라
    // 등록이 조용히 건너뛰어진다 — 채널에 핸들러가 없으니 Dart 쪽
    // 호출이 전부 MissingPluginException 으로 삼켜져 아무 일도 안 난다
    if let controller = window?.rootViewController as? FlutterViewController {
      TripActivityBridge.register(with: controller)
    }

    return launched
  }
}
