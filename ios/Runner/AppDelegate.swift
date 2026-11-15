import Flutter
import UIKit
import UserNotifications
// Gene - Nov, 15, 2026: Import flutter_local_notifications so the UIScene implicit engine delegate can register background notification action plugins.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Show timer alarms even while the app is in the foreground; without a
    // delegate iOS silently swallows them there.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Gene - Nov, 15, 2026: Preserved original didInitializeImplicitFlutterEngine without notification registrant callback.
  // func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
  //   GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  // }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
