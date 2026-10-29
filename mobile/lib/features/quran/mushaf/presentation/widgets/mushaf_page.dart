import 'package:flutter/foundation.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../../../../core/design/design.dart';

/// One Mushaf page with its own pinch / double-tap zoom (1x–4x).
///
/// Each page owns its [InteractiveViewer] so the surrounding [PageView] keeps
/// the horizontal swipe; the screen turns swiping off while [onZoomChanged]
/// reports a zoomed page. The zoom resets when [currentPage] moves away.
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.page,
    required this.theme,
    required this.currentPage,
    required this.sp,
    required this.h,
    required this.highlightColor,
    required this.onTap,
    required this.onZoomChanged,
    required this.onAyahLongPress,
    this.selected,
  });

  final int page;
  final QcfThemeData theme;
  final ValueListenable<int> currentPage;

  /// qcf_quran's font and line-height scale factors (its ScreenUtil `sp` / `h`).
  final double sp;
  final double h;

  final Color highlightColor;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final void Function(int surah, int ayah) onAyahLongPress;

  /// The highlighted ayah, if it is on this page.
  final ({int surah, int ayah})? selected;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage>
    with SingleTickerProviderStateMixin {
  static const double _maxScale = 4;
  static const double _doubleTapScale = 2.5;

  final _transform = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _zoomTween;
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  // The page's text spans are rebuilt only when what they show changes, not
  // on every overlay toggle of the screen.
  Widget? _content;
  Object? _contentKey;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: AppMotion.standard)
      ..addListener(() => _transform.value = _zoomTween!.value);
    _transform.addListener(_onTransform);
    widget.currentPage.addListener(_onCurrentPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animation.duration = AppMotion.of(context);
  }

  @override
  void didUpdateWidget(MushafPage old) {
    super.didUpdateWidget(old);
    if (old.currentPage != widget.currentPage) {
      old.currentPage.removeListener(_onCurrentPage);
      widget.currentPage.addListener(_onCurrentPage);
    }
  }

  @override
  void dispose() {
    widget.currentPage.removeListener(_onCurrentPage);
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    if (widget.currentPage.value == widget.page) widget.onZoomChanged(zoomed);
  }

  void _onCurrentPage() {
    if (widget.currentPage.value == widget.page || !_zoomed) return;
    _animation.stop();
    _transform.value = Matrix4.identity();
  }

  void _onDoubleTap() {
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      // Scale around the tapped point so it stays under the finger.
      const s = _doubleTapScale;
      end = Matrix4.identity()
        ..translateByDouble(
            -_doubleTapAt.dx * (s - 1), -_doubleTapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: end)
        .animate(CurvedAnimation(parent: _animation, curve: AppMotion.curve));
    _animation.forward(from: 0);
  }

  Widget _buildContent() {
    final key = (
      widget.theme,
      widget.selected,
      widget.highlightColor,
      widget.sp,
      widget.h,
    );
    if (_content != null && key == _contentKey) return _content!;
    final selected = widget.selected;
    _contentKey = key;
    return _content = PrimaryScrollController.none(
      // QcfPage lays its text out in a vertical list the height of the
      // screen, which scrolls pages taller than the screen at 1x.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: QcfPage(
          pageNumber: widget.page,
          theme: widget.theme,
          sp: widget.sp,
          h: widget.h,
          onLongPress: widget.onAyahLongPress,
          verseBackgroundColor: selected == null
              ? null
              : (s, v) => s == selected.surah && v == selected.ayah
                  ? widget.highlightColor
                  : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: _maxScale,
      // At 1x a one-finger drag belongs to the PageView.
      panEnabled: _zoomed,
      onInteractionStart: (_) => _animation.stop(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
        onDoubleTap: _onDoubleTap,
        // That list is always-scrollable (QcfPage doesn't let us change its
        // physics), so while zoomed it would take every vertical drag and
        // the zoomed page could only pan sideways. Ignoring touches on the
        // text hands those drags to the InteractiveViewer; the ayah
        // long-press works at 1x only.
        child: IgnorePointer(ignoring: _zoomed, child: _buildContent()),
      ),
    );
  }
}
