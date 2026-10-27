import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/call_session.dart';
import '../domain/fajr_call_list.dart';

/// What the Android call engine is allowed to do right now.
class FajrNativePermissions {
  const FajrNativePermissions({
    this.callPhone = false,
    this.phoneState = false,
    this.answerCalls = false,
    this.callLog = false,
    this.callLogAvailable = false,
    this.ignoringBatteryOptimizations = false,
  });

  /// `CALL_PHONE`: required to place calls.
  final bool callPhone;

  /// `READ_PHONE_STATE`: required to follow each call.
  final bool phoneState;

  /// `ANSWER_PHONE_CALLS`: lets the app hang up when the ring time is over.
  final bool answerCalls;

  /// `READ_CALL_LOG` granted (only in builds that declare it).
  final bool callLog;

  /// This build declares `READ_CALL_LOG` (see the `callLog` build flag).
  final bool callLogAvailable;

  /// Exempt from battery optimisation (Doze / OEM killers).
  final bool ignoringBatteryOptimizations;

  /// The minimum for auto mode.
  bool get canAutoCall => callPhone && phoneState;

  factory FajrNativePermissions.fromMap(Map<dynamic, dynamic> m) =>
      FajrNativePermissions(
        callPhone: m['callPhone'] == true,
        phoneState: m['phoneState'] == true,
        answerCalls: m['answerCalls'] == true,
        callLog: m['callLog'] == true,
        callLogAvailable: m['callLogAvailable'] == true,
        ignoringBatteryOptimizations:
            m['ignoringBatteryOptimizations'] == true,
      );
}

/// A SIM / calling account the user can call from (dual-SIM phones).
class PhoneAccountOption {
  const PhoneAccountOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Strings the native side shows (ongoing notification), sent from Flutter
/// because the app language is an in-app setting, not the device's.
class FajrNativeStrings {
  const FajrNativeStrings({
    required this.channelName,
    required this.title,
    required this.callingTemplate,
    required this.waitingText,
    required this.stopLabel,
    required this.doneText,
  });

  final String channelName;
  final String title;

  /// Contains `%s` for the contact name.
  final String callingTemplate;
  final String waitingText;
  final String stopLabel;
  final String doneText;

  Map<String, String> toMap() => {
        'channelName': channelName,
        'title': title,
        'calling': callingTemplate,
        'waiting': waitingText,
        'stop': stopLabel,
        'done': doneText,
      };
}

/// Bridge to the Android call engine (`lahuma/fajr_call`).
///
/// Native code is the source of truth at fire time: every save sends the
/// full config of the enabled auto lists with their precomputed fire times,
/// and the engine runs even when Flutter is not. On iOS, or before the
/// engine exists, every call degrades to "not supported" so the feature
/// falls back to manual mode.
class FajrCallPlatform {
  const FajrCallPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('lahuma/fajr_call');

  final MethodChannel _channel;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('fajr_call.$method failed: ${e.code} ${e.message}');
      return null;
    }
  }

  /// True when this device can place calls automatically.
  Future<bool> isAutoCallSupported() async =>
      await _invoke<bool>('isSupported') ?? false;

  /// Replaces the native schedule. [lists] are the enabled auto lists, each
  /// with its upcoming fire times (epoch millis, ascending).
  Future<void> sync({
    required List<({FajrCallList list, List<DateTime> fireTimes})> lists,
    required FajrNativeStrings strings,
  }) =>
      _invoke<void>('sync', {
        'config': jsonEncode({
          'lists': [
            for (final e in lists)
              {
                ...e.list.toJson(),
                'fireTimes': [
                  for (final t in e.fireTimes) t.millisecondsSinceEpoch,
                ],
              },
          ],
          'strings': strings.toMap(),
        }),
      });

  /// Runs [list] immediately ("Test now").
  Future<bool> runNow(FajrCallList list, FajrNativeStrings strings) async =>
      await _invoke<bool>('runNow', {
        'list': jsonEncode(list.toJson()),
        'strings': strings.toMap(),
      }) ??
      false;

  /// Stops a running call loop.
  Future<void> stop() => _invoke<void>('stop');

  /// Sessions the engine finished since the last call; they are removed
  /// from native storage once returned.
  Future<List<CallSession>> takeSessions() async {
    final raw = await _invoke<String>('takeSessions');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final s in json)
          if (s is Map) CallSession.fromJson(Map<String, dynamic>.from(s)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<FajrNativePermissions> permissions() async {
    final m = await _invoke<Map<dynamic, dynamic>>('permissions');
    return m == null
        ? const FajrNativePermissions()
        : FajrNativePermissions.fromMap(m);
  }

  /// Shows the system prompt for the call permissions (CALL_PHONE,
  /// READ_PHONE_STATE, ANSWER_PHONE_CALLS and, in call-log builds,
  /// READ_CALL_LOG). Returns the resulting state.
  Future<FajrNativePermissions> requestCallPermissions() async {
    final m = await _invoke<Map<dynamic, dynamic>>('requestCallPermissions');
    return m == null
        ? const FajrNativePermissions()
        : FajrNativePermissions.fromMap(m);
  }

  /// Asks to be exempted from battery optimisation (system dialog).
  Future<void> requestIgnoreBatteryOptimizations() =>
      _invoke<void>('requestIgnoreBatteryOptimizations');

  /// Opens the app's system settings page (for OEM autostart switches).
  Future<void> openAppSettings() => _invoke<void>('openAppSettings');

  Future<List<PhoneAccountOption>> phoneAccounts() async {
    final raw = await _invoke<List<dynamic>>('phoneAccounts');
    return [
      for (final a in raw ?? const [])
        if (a is Map)
          PhoneAccountOption(
              id: '${a['id']}', label: '${a['label'] ?? a['id']}'),
    ];
  }
}
