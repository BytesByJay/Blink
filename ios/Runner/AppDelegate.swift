import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  UNUserNotificationCenterDelegate
{
  private var alarmKit: AlarmKitPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Kept deliberately even though iOS now schedules breaks through AlarmKit.
    // FlutterAppDelegate implements the UNUserNotificationCenterDelegate
    // callbacks and forwards them to plugins but does not declare the
    // conformance, so without this any notification Blink does show while it is
    // open is dropped silently and its taps are never reported.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let plugin = AlarmKitPlugin(messenger: engineBridge.binaryMessenger)
    plugin.register()
    alarmKit = plugin
  }
}
