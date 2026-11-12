import ActivityKit
import Foundation

/// The prayer-times Live Activity's data. Compiled into both the app
/// (Runner, which starts and updates it) and the PrayerBanner widget
/// extension (which draws it). Dart side:
/// `lib/features/prayer_banner/data/prayer_banner_platform.dart`.
@available(iOS 16.2, *)
struct PrayerBannerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// Fajr, Dhuhr, Asr, Maghrib, Isha, in the app's language.
    var names: [String]
    /// Those five prayers' times on the day shown.
    var times: [Date]
    /// Index into [names] / [times] of the prayer that comes next.
    var next: Int
    /// When the count-down started (the prayer before, or midnight).
    var since: Date
    /// The word before the count-down ("in", «بعد»).
    var countdown: String
    var rtl: Bool

    var nextName: String { names.indices.contains(next) ? names[next] : "" }
    var nextTime: Date { times.indices.contains(next) ? times[next] : Date() }
    /// The count-down's range; never reversed, which SwiftUI rejects.
    var countdownRange: ClosedRange<Date> { min(since, nextTime)...nextTime }
  }
}
