import '../../prayer_times/domain/prayer_times.dart';

/// The five prayers that get an adhan (no Sunrise), in daily order.
const List<PrayerKind> adhanPrayers = [
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
];

/// What a prayer gets at its time.
enum AdhanMode {
  /// The full adhan (Android: from the alarm, even with the app closed;
  /// iOS: a 30-second clip, the full adhan on tap).
  adhan,

  /// A notification without sound.
  silent,

  /// Nothing.
  off,
}

/// Reminder lead times offered in the settings screen; 0 is off.
const List<int> adhanReminderOptions = [0, 5, 10, 15, 20, 30];

/// The user's adhan choices. Everything stays on the device.
class AdhanSettings {
  const AdhanSettings({
    this.enabled = false,
    this.muezzinId,
    this.prayers = const {...adhanPrayers},
    this.silent = const {},
    this.reminderMinutes = 0,
  });

  /// Master switch. Off until the user turns it on, which is when the
  /// notification permission is asked.
  final bool enabled;

  /// The chosen muezzin; null plays the bundled default adhan.
  final String? muezzinId;

  /// The prayers that aren't [AdhanMode.off].
  final Set<PrayerKind> prayers;

  /// Of [prayers], those that only get a silent notification.
  final Set<PrayerKind> silent;

  /// "اقترب وقت صلاة …" this many minutes before; 0 = no reminder.
  final int reminderMinutes;

  bool plays(PrayerKind prayer) => enabled && modeOf(prayer) == AdhanMode.adhan;

  AdhanMode modeOf(PrayerKind prayer) => !prayers.contains(prayer)
      ? AdhanMode.off
      : silent.contains(prayer)
          ? AdhanMode.silent
          : AdhanMode.adhan;

  AdhanSettings withMode(PrayerKind prayer, AdhanMode mode) {
    final on = {...prayers};
    final quiet = {...silent};
    mode == AdhanMode.off ? on.remove(prayer) : on.add(prayer);
    mode == AdhanMode.silent ? quiet.add(prayer) : quiet.remove(prayer);
    return copyWith(prayers: on, silent: quiet);
  }

  AdhanSettings copyWith({
    bool? enabled,
    String? muezzinId,
    Set<PrayerKind>? prayers,
    Set<PrayerKind>? silent,
    int? reminderMinutes,
  }) =>
      AdhanSettings(
        enabled: enabled ?? this.enabled,
        muezzinId: muezzinId ?? this.muezzinId,
        prayers: prayers ?? this.prayers,
        silent: silent ?? this.silent,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (muezzinId != null) 'muezzinId': muezzinId,
        'prayers': [
          for (final p in adhanPrayers)
            if (prayers.contains(p)) p.name
        ],
        'silent': [
          for (final p in adhanPrayers)
            if (silent.contains(p)) p.name
        ],
        'reminderMinutes': reminderMinutes,
      };

  factory AdhanSettings.fromJson(Map<String, dynamic> json) {
    final names = (json['prayers'] as List?)?.cast<Object?>();
    // Missing before per-prayer modes: every enabled prayer had the adhan.
    final quiet = (json['silent'] as List?)?.cast<Object?>() ?? const [];
    final minutes = (json['reminderMinutes'] as num?)?.toInt() ?? 0;
    return AdhanSettings(
      enabled: json['enabled'] == true,
      muezzinId: json['muezzinId'] as String?,
      prayers: names == null
          ? const {...adhanPrayers}
          : {
              for (final p in adhanPrayers)
                if (names.contains(p.name)) p
            },
      silent: {
        for (final p in adhanPrayers)
          if (quiet.contains(p.name)) p
      },
      reminderMinutes: adhanReminderOptions.contains(minutes) ? minutes : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanSettings &&
      other.enabled == enabled &&
      other.muezzinId == muezzinId &&
      other.reminderMinutes == reminderMinutes &&
      other.prayers.length == prayers.length &&
      other.prayers.containsAll(prayers) &&
      other.silent.length == silent.length &&
      other.silent.containsAll(silent);

  @override
  int get hashCode => Object.hash(enabled, muezzinId, reminderMinutes,
      Object.hashAllUnordered(prayers), Object.hashAllUnordered(silent));
}
