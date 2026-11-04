import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../domain/player_backdrop.dart';

/// Full-bleed animated background for the Now Playing screen.
///
/// Transparent for [PlayerBackdrop.none], while a video loads, and if it
/// fails, so the screen's own gradient shows through. Switching scenes
/// crossfades: the incoming video fades in over the outgoing one, which
/// stays opaque for the first half of the switch so the bare gradient never
/// flashes between two scenes. With reduced motion on, the poster frame is
/// shown as a still.
class PlayerBackdropLayer extends StatelessWidget {
  const PlayerBackdropLayer({super.key, required this.backdrop});

  final PlayerBackdrop backdrop;

  static const _switch = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final Widget child;
    if (!backdrop.hasVideo) {
      child = const SizedBox.expand(key: ValueKey('none'));
    } else if (still) {
      child = Image.asset(
        backdrop.poster,
        key: ValueKey('still-${backdrop.name}'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    } else {
      child = _LoopingVideo(key: ValueKey(backdrop), backdrop: backdrop);
    }

    return AnimatedSwitcher(
      duration: _switch,
      // Incoming reaches full opacity at the midpoint; outgoing (the same
      // curve, reversed) holds until the midpoint, then fades.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: CurvedAnimation(
            parent: animation, curve: const Interval(0, 0.5)),
        child: child,
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}

/// One muted, looping asset video, scaled to cover. Owns its controller:
/// created when the scene is shown, disposed when it leaves (including after
/// the crossfade out), so switching repeatedly does not pile up decoders.
class _LoopingVideo extends StatefulWidget {
  const _LoopingVideo({super.key, required this.backdrop});

  final PlayerBackdrop backdrop;

  @override
  State<_LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<_LoopingVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller = VideoPlayerController.asset(
    widget.backdrop.video,
    // The clips have no audio track; this keeps the platform player from
    // taking audio focus (Android) or the audio session (iOS) away from the
    // recitation.
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      if (!mounted) return;
      if (_inForeground) await _controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _inForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.expand();
    final size = _controller.value.size;
    return AnimatedOpacity(
      opacity: _ready ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: !_ready || size.isEmpty
          ? const SizedBox.expand()
          : SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
    );
  }
}
