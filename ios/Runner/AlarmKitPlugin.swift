import AlarmKit
import Flutter
import Foundation
import SwiftUI

/// Bridges `AlarmKitNotifier` to AlarmKit.
///
/// One alarm per break. It alerts at break time; its "Look away" button uses
/// `.countdown` behaviour so AlarmKit runs the look-away countdown itself as
/// the `postAlert` duration, rendered by BlinkAlarmWidget.
final class AlarmKitPlugin {
  private let channel: FlutterMethodChannel
  private var scheduled: [UUID] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "blink/alarmkit", binaryMessenger: messenger)
  }

  func register() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      Task { await self.handle(call, result) }
    }
  }

  private func handle(
    _ call: FlutterMethodCall, _ result: @escaping FlutterResult
  ) async {
    switch call.method {
    case "authorizationStatus":
      result(AlarmManager.shared.authorizationState == .authorized)

    case "requestAuthorization":
      do {
        let state = try await AlarmManager.shared.requestAuthorization()
        result(state == .authorized)
      } catch {
        result(false)
      }

    case "pendingCount":
      result(scheduled.count)

    case "cancelAll":
      cancelAll()
      result(nil)

    case "schedule":
      guard
        let args = call.arguments as? [String: Any],
        let alarms = args["alarms"] as? [[String: Any]]
      else {
        result(
          FlutterError(
            code: "bad_args", message: "alarms missing", details: nil))
        return
      }
      do {
        try await schedule(alarms)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "schedule_failed",
            message: error.localizedDescription,
            details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cancelAll() {
    for id in scheduled {
      try? AlarmManager.shared.cancel(id: id)
    }
    scheduled.removeAll()
  }

  private func schedule(_ alarms: [[String: Any]]) async throws {
    cancelAll()

    for alarm in alarms {
      guard
        let atMs = alarm["atEpochMs"] as? NSNumber,
        let lookAway = alarm["lookAwaySeconds"] as? NSNumber
      else { continue }

      let breakStart = Date(timeIntervalSince1970: atMs.doubleValue / 1000)

      let alert = AlarmPresentation.Alert(
        title: "Time to rest your eyes",
        stopButton: .init(
          text: "Skip", textColor: .white, systemImageName: "xmark"),
        secondaryButton: .init(
          text: "Look away", textColor: .white, systemImageName: "eye"),
        secondaryButtonBehavior: .countdown
      )

      let attributes = BlinkAlarmAttributes(
        presentation: AlarmPresentation(alert: alert),
        metadata: BlinkAlarmMetadata(),
        tintColor: .teal
      )

      let configuration = AlarmManager.AlarmConfiguration(
        schedule: .fixed(breakStart),
        attributes: attributes,
        countdownDuration: .init(
          preAlert: nil, postAlert: lookAway.doubleValue)
      )

      let id = UUID()
      _ = try await AlarmManager.shared.schedule(
        id: id, configuration: configuration)
      scheduled.append(id)
    }
  }
}
