import 'dart:async';

import 'package:flutter/foundation.dart';

/// Stops a player after a chosen time, or at the end of the current track.
///
/// Counts against the wall clock, not by adding up ticks, so a phone that
/// slept through some ticks still stops on time. Over the last [fadeLength]
/// it reports a volume factor from 1 down to 0 through [onFade], so the
/// recitation fades out instead of cutting off; then [onExpire] runs once.
/// The player restores its volume itself after pausing.
class SleepTimer extends ChangeNotifier {
  SleepTimer({
    required this.onFade,
    required this.onExpire,
    this.fadeLength = const Duration(seconds: 8),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Volume factor, 1 (untouched) … 0 (silent).
  final void Function(double factor) onFade;
  final void Function() onExpire;
  final Duration fadeLength;
  final DateTime Function() _now;

  Timer? _ticker;
  DateTime? _endsAt;
  bool _endOfTrack = false;
  Duration? _chosen;
  int _shownSeconds = -1;
  bool _fading = false;

  /// A countdown or end-of-track stop is set.
  bool get isActive => _endsAt != null || _endOfTrack;

  /// Stops when the current track ends instead of after a time.
  bool get endOfTrack => _endOfTrack;

  /// The length picked for the running countdown (to mark it in a picker).
  Duration? get chosen => _chosen;

  /// Time left on the countdown, rounded up to the second; null when none.
  Duration? get remaining {
    final end = _endsAt;
    if (end == null) return null;
    final left = end.difference(_now());
    if (left <= Duration.zero) return Duration.zero;
    return Duration(seconds: (left.inMilliseconds / 1000).ceil());
  }

  /// Starts (or restarts) a countdown of [length].
  void start(Duration length) {
    _clear();
    _chosen = length;
    _endsAt = _now().add(length);
    // Fine-grained enough for a smooth fade; listeners hear once a second.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _tick();
  }

  /// Stops once the current track finishes (see [takeEndOfTrack]).
  void startEndOfTrack() {
    _clear();
    _endOfTrack = true;
    notifyListeners();
  }

  void cancel() {
    if (!isActive) return;
    _clear();
    notifyListeners();
  }

  /// For the player's track-completed handler: true (and the timer is done)
  /// when it should stop here instead of moving on to the next track.
  bool takeEndOfTrack() {
    if (!_endOfTrack) return false;
    _clear();
    notifyListeners();
    return true;
  }

  void _tick() {
    final end = _endsAt;
    if (end == null) return;
    final left = end.difference(_now());
    if (left <= Duration.zero) {
      // Silent, and left silent: restoring the volume before the player has
      // paused would blip the recitation back at full volume.
      onFade(0);
      _fading = false;
      _clear();
      onExpire();
      notifyListeners();
      return;
    }
    if (left <= fadeLength) {
      _fading = true;
      onFade(left.inMilliseconds / fadeLength.inMilliseconds);
    }
    final seconds = remaining!.inSeconds;
    if (seconds != _shownSeconds) {
      _shownSeconds = seconds;
      notifyListeners();
    }
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _endOfTrack = false;
    _chosen = null;
    _shownSeconds = -1;
    // Cancelled mid-fade: back to full volume.
    if (_fading) {
      _fading = false;
      onFade(1);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
