import '../../../../../core/design/design.dart';

/// A miniature on an introduction page. It plays while [active] (its page
/// is the current one) and rests otherwise.
abstract class OnboardingArtWidget extends StatefulWidget {
  const OnboardingArtWidget({super.key, required this.active});

  final bool active;
}

/// Drives an [OnboardingArtWidget]: [timeline] plays once, from the start,
/// each time the page becomes current and holds its last frame; [ambient]
/// (when [ambientLength] is set) loops underneath for things that keep
/// moving, like a waveform. Both stop when the page is left. With Reduce
/// Motion the miniature shows its last frame and nothing moves.
abstract class OnboardingArtState<T extends OnboardingArtWidget>
    extends State<T> with TickerProviderStateMixin {
  Duration get length;

  /// The loop's period, or null for none.
  Duration? get ambientLength => null;

  late final AnimationController timeline =
      AnimationController(vsync: this, duration: length);
  late final AnimationController ambient = AnimationController(
      vsync: this, duration: ambientLength ?? const Duration(seconds: 1));

  bool get still => MediaQuery.disableAnimationsOf(context);

  /// Part [startMs]…[endMs] of [timeline] as 0 → 1.
  Animation<double> segment(int startMs, int endMs,
      [Curve curve = Curves.easeOutCubic]) {
    final total = length.inMilliseconds;
    return CurvedAnimation(
      parent: timeline,
      curve: Interval(
          (startMs / total).clamp(0.0, 1.0), (endMs / total).clamp(0.0, 1.0),
          curve: curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(restart: false);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync(restart: widget.active);
  }

  void _sync({required bool restart}) {
    if (still) {
      timeline.value = 1;
      ambient.stop();
      return;
    }
    if (!widget.active) {
      timeline.stop();
      ambient.stop();
      return;
    }
    if (restart || (!timeline.isAnimating && timeline.value == 0)) {
      timeline.forward(from: 0);
    }
    if (ambientLength != null && !ambient.isAnimating) ambient.repeat();
  }

  @override
  void dispose() {
    timeline.dispose();
    ambient.dispose();
    super.dispose();
  }
}
