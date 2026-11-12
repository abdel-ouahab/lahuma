import ActivityKit
import SwiftUI
import WidgetKit

/// The prayer-times banner on the lock screen and in the Dynamic Island:
/// the next prayer, a count-down iOS ticks by itself, and the five times.
/// It can't move on to the following prayer by itself (no push server), so
/// once the time passes it dims (stale) until the app is opened again.
@available(iOS 16.2, *)
struct PrayerBannerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrayerBannerAttributes.self) { context in
      LockScreenView(state: context.state, stale: context.isStale)
        .activityBackgroundTint(Palette.green)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(s.nextName).font(.headline).foregroundColor(Palette.gold)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: s).font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          TimesRow(state: s, stale: context.isStale)
        }
      } compactLeading: {
        Text(s.nextName).font(.caption2).foregroundColor(Palette.gold)
      } compactTrailing: {
        Text(timerInterval: s.countdownRange, countsDown: true)
          .monospacedDigit()
          .font(.caption2)
          .frame(maxWidth: 52)
      } minimal: {
        Image(systemName: "moon.stars.fill").foregroundColor(Palette.gold)
      }
      .keylineTint(Palette.gold)
    }
  }
}

private enum Palette {
  /// Mosque green (Android's notification accent, `#0F5A4A`).
  static let green = Color(red: 15 / 255, green: 90 / 255, blue: 74 / 255)
  /// The app's gold (`#D9B45A`).
  static let gold = Color(red: 217 / 255, green: 180 / 255, blue: 90 / 255)
}

/// 24-hour HH:mm, as on Home.
private let hhmm: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "en_US_POSIX")
  f.dateFormat = "HH:mm"
  return f
}()

@available(iOS 16.2, *)
private struct Countdown: View {
  let state: PrayerBannerAttributes.ContentState

  var body: some View {
    HStack(spacing: 4) {
      Text(state.countdown).foregroundColor(.white.opacity(0.75))
      Text(timerInterval: state.countdownRange, countsDown: true)
        .monospacedDigit()
        .foregroundColor(.white)
    }
  }
}

@available(iOS 16.2, *)
private struct TimesRow: View {
  let state: PrayerBannerAttributes.ContentState
  let stale: Bool

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(zip(state.names.indices, state.names)), id: \.0) { i, name in
        let next = i == state.next && !stale
        VStack(spacing: 2) {
          Text(name).font(.caption2)
          Text(state.times.indices.contains(i) ? hhmm.string(from: state.times[i]) : "")
            .font(.footnote.weight(next ? .bold : .regular))
            .monospacedDigit()
        }
        .foregroundColor(next ? Palette.gold : .white.opacity(0.8))
        .frame(maxWidth: .infinity)
      }
    }
  }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
  let state: PrayerBannerAttributes.ContentState
  let stale: Bool

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text(state.nextName).font(.headline).foregroundColor(.white)
        Text(hhmm.string(from: state.nextTime))
          .font(.headline)
          .monospacedDigit()
          .foregroundColor(Palette.gold)
        Spacer()
        if !stale { Countdown(state: state).font(.subheadline) }
      }
      Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
      TimesRow(state: state, stale: stale)
    }
    .padding(16)
    .opacity(stale ? 0.7 : 1)
    .environment(\.layoutDirection, state.rtl ? .rightToLeft : .leftToRight)
  }
}
