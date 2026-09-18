import AlarmKit
import Foundation

/// Shared between the app and the widget extension, so both describe the same
/// alarm shape. AlarmKit requires a metadata type even when it carries nothing.
nonisolated struct BlinkAlarmMetadata: AlarmMetadata {
  init() {}
}

typealias BlinkAlarmAttributes = AlarmAttributes<BlinkAlarmMetadata>
