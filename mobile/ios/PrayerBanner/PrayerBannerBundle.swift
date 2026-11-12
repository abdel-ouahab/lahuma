import SwiftUI
import WidgetKit

/// The PrayerBanner extension: only the prayer-times Live Activity.
@main
struct PrayerBannerBundle: WidgetBundle {
  var body: some Widget {
    // The extension's deployment target is iOS 16.2.
    PrayerBannerLiveActivity()
  }
}
