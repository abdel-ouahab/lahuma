import ActivityKit
import Flutter
import Foundation

/// `lahuma/prayer_banner`: starts, updates and ends the prayer-times Live
/// Activity (drawn by the PrayerBanner extension). Called whenever the app
/// runs; iOS only lets an activity start from the foreground.
enum PrayerBannerChannel {
  /// iOS ends an activity after 8 hours: restart it well before.
  private static let restartAfter: TimeInterval = 4 * 3600
  private static let startedAtKey = "prayerBanner.startedAt"

  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "lahuma/prayer_banner", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }
      switch call.method {
      case "show":
        guard let state = state(from: call.arguments) else {
          result(FlutterError(code: "bad_args", message: "Missing banner data", details: nil))
          return
        }
        Task {
          await show(state)
          result(nil)
        }
      case "end":
        Task {
          await endAll()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 16.2, *)
  private static func state(from arguments: Any?) -> PrayerBannerAttributes.ContentState? {
    guard let a = arguments as? [String: Any],
          let names = a["names"] as? [String],
          let times = a["times"] as? [NSNumber],
          let next = a["next"] as? Int,
          let since = a["since"] as? NSNumber,
          names.count == times.count, times.indices.contains(next)
    else { return nil }
    func date(_ ms: NSNumber) -> Date { Date(timeIntervalSince1970: ms.doubleValue / 1000) }
    return PrayerBannerAttributes.ContentState(
      names: names,
      times: times.map(date),
      next: next,
      since: date(since),
      countdown: a["countdown"] as? String ?? "",
      rtl: a["rtl"] as? Bool ?? false
    )
  }

  @available(iOS 16.2, *)
  private static func show(_ state: PrayerBannerAttributes.ContentState) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    // Stale once the prayer has come: the widget dims until the next update.
    let content = ActivityContent(state: state, staleDate: state.nextTime)
    let running = Activity<PrayerBannerAttributes>.activities
    let startedAt = UserDefaults.standard.double(forKey: startedAtKey)
    let fresh = Date().timeIntervalSince1970 - startedAt < restartAfter
    if fresh, let current = running.first(where: { $0.activityState == .active }) {
      await current.update(content)
      for other in running where other.id != current.id {
        await other.end(nil, dismissalPolicy: .immediate)
      }
      return
    }
    for a in running { await a.end(nil, dismissalPolicy: .immediate) }
    do {
      _ = try Activity.request(attributes: PrayerBannerAttributes(), content: content, pushType: nil)
      UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: startedAtKey)
    } catch {
      NSLog("PrayerBanner: could not start the Live Activity: \(error)")
    }
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for a in Activity<PrayerBannerAttributes>.activities {
      await a.end(nil, dismissalPolicy: .immediate)
    }
    UserDefaults.standard.removeObject(forKey: startedAtKey)
  }
}
