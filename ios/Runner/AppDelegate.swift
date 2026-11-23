import Flutter
import UIKit
import UserNotifications
// Gene - Nov, 15, 2026: Import flutter_local_notifications so the UIScene implicit engine delegate can register background notification action plugins.
import flutter_local_notifications

// Gene - Nov, 22, 2026: Preserved original AppDelegate and added platform MethodChannel (timezone + notification settings) and foreground banner/sound suppression via UNUserNotificationCenterDelegate.
// @main
// @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     // Show timer alarms even while the app is in the foreground; without a
//     // delegate iOS silently swallows them there.
//     if #available(iOS 10.0, *) {
//       UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
//     }
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
//
//   // Gene - Nov, 15, 2026: Preserved original didInitializeImplicitFlutterEngine without notification registrant callback.
//   // func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
//   //   GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
//   // }
//   func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
//     FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
//       GeneratedPluginRegistrant.register(with: registry)
//     }
//     if #available(iOS 10.0, *) {
//       UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
//     }
//     GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
//   }
// }
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "dev.genexis.activitytimer/platform",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getLocalTimezone":
        result(TimeZone.current.identifier)
      case "openNotificationSettings":
        DispatchQueue.main.async {
          let targetUrlString: String
          if #available(iOS 16.0, *) {
            targetUrlString = UIApplication.openNotificationSettingsURLString
          } else {
            targetUrlString = UIApplication.openSettingsURLString
          }
          guard let url = URL(string: targetUrlString) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.platformChannel = channel
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Suppress OS banner and audio while active in foreground because CuePlayer owns foreground audio.
    if UIApplication.shared.applicationState == .active {
      completionHandler([])
      return
    }

    let userInfo = notification.request.content.userInfo
    let presentSound = (userInfo["presentSound"] as? Bool ?? false) && (notification.request.content.sound != nil)
    let presentAlert = userInfo["presentAlert"] as? Bool ?? true
    let presentBanner = userInfo["presentBanner"] as? Bool ?? true
    let presentList = userInfo["presentList"] as? Bool ?? true

    var options: UNNotificationPresentationOptions = []
    if #available(iOS 14.0, *) {
      if presentBanner {
        options.insert(.banner)
      }
      if presentList {
        options.insert(.list)
      }
    } else if presentAlert {
      options.insert(.alert)
    }
    if presentSound {
      options.insert(.sound)
    }
    completionHandler(options)
  }
}
