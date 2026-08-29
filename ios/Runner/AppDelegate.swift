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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
