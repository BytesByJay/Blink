import AlarmKit
import SwiftUI
import WidgetKit

/// Renders the look-away countdown on the Lock Screen, StandBy and Dynamic
/// Island. AlarmKit requires this: scheduling an alarm with a countdown and no
/// Live Activity risks the system dismissing it instead of alerting.
struct BlinkAlarmWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BlinkAlarmAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: "eye")
          .font(.title2)
        VStack(alignment: .leading, spacing: 4) {
          Text("Look 20 feet away")
            .font(.headline)
          countdown(for: context.state)
            .font(.title3.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding()
      .activityBackgroundTint(.black.opacity(0.85))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "eye").font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          countdown(for: context.state).font(.title2.monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("Look 20 feet away").font(.headline)
        }
      } compactLeading: {
        Image(systemName: "eye")
      } compactTrailing: {
        countdown(for: context.state).monospacedDigit()
      } minimal: {
        Image(systemName: "eye")
      }
      .keylineTint(.teal)
    }
  }

  /// AlarmKit hands the widget the countdown's end date; `Text(timerInterval:)`
  /// is rendered live by the system, so the widget never needs an update.
  @ViewBuilder
  private func countdown(for state: AlarmPresentationState) -> some View {
    if case let .countdown(countdown) = state.mode {
      Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
    } else {
      Text("--:--")
    }
  }
}
