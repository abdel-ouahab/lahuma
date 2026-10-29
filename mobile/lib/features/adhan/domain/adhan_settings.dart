import '../../prayer_times/domain/prayer_times.dart';

/// The five prayers that get an adhan (no Sunrise), in daily order.
const List<PrayerKind> adhanPrayers = [
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
];

/// Reminder lead times offered in the settings screen; 0 is off.
const List<int> adhanReminderOptions = [0, 5, 10, 15, 20, 30];

/// The user's adhan choices. Everything stays on the device.
class AdhanSettings {
  const AdhanSettings({
    this.enabled = false,
    this.muezzinId,
    this.prayers = const {...adhanPrayers},
    this.reminderMinutes = 0,
  });

  /// Master switch. Off until the user turns it on, which is when the
  /// notification permission is asked.
  final bool enabled;

  /// The chosen muezzin; null plays the bundled default adhan.
  final String? muezzinId;
  final Set<PrayerKind> prayers;

  /// "اقترب وقت صلاة …" this many minutes before; 0 = no reminder.
  final int reminderMinutes;

  bool plays(PrayerKind prayer) => enabled && prayers.contains(prayer);

  AdhanSettings copyWith({
    bool? enabled,
    String? muezzinId,
    Set<PrayerKind>? prayers,
    int? reminderMinutes,
  }) =>
      AdhanSettings(
        enabled: enabled ?? this.enabled,
        muezzinId: muezzinId ?? this.muezzinId,
        prayers: prayers ?? this.prayers,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (muezzinId != null) 'muezzinId': muezzinId,
        'prayers': [
          for (final p in adhanPrayers)
            if (prayers.contains(p)) p.name
        ],
        'reminderMinutes': reminderMinutes,
      };

  factory AdhanSettings.fromJson(Map<String, dynamic> json) {
    final names = (json['prayers'] as List?)?.cast<Object?>();
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
      other.prayers.containsAll(prayers);

  @override
  int get hashCode => Object.hash(
      enabled, muezzinId, reminderMinutes, Object.hashAllUnordered(prayers));
}
