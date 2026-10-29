import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import '../../localization/tr.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

// Cupertino dialogs and action sheets hard-code the SF family. On platforms
// without SF that falls back to the platform font, so carry over ours.
TextStyle _family(TextStyle s) => TextStyle(
    fontFamily: s.fontFamily, fontFamilyFallback: s.fontFamilyFallback);

// ─── Alert dialog ──────────────────────────────────────────────────────────

class AppDialogAction<T> {
  const AppDialogAction({
    required this.label,
    this.value,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;

  /// Returned by [showAppDialog] when this action is chosen.
  final T? value;
  final bool isDefault;
  final bool isDestructive;
}

/// iOS alert. Returns the chosen action's `value` (null if none).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<AppDialogAction<T>> actions,
}) {
  return showCupertinoDialog<T>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title, style: _family(AppTypography.headline)),
      content: message == null
          ? null
          : Text(message, style: _family(AppTypography.footnote)),
      actions: [
        for (final a in actions)
          CupertinoDialogAction(
            isDefaultAction: a.isDefault,
            isDestructiveAction: a.isDestructive,
            textStyle: _family(
                a.isDefault ? AppTypography.headline : AppTypography.body),
            onPressed: () {
              if (a.isDestructive || a.isDefault) HapticFeedback.lightImpact();
              Navigator.of(ctx).pop(a.value);
            },
            child: Text(a.label),
          ),
      ],
    ),
  );
}

/// Alert with a text field. Returns the text on confirm, null on cancel.
Future<String?> showAppTextInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? placeholder,
  String? confirmLabel,
  String? cancelLabel,
  int maxLines = 1,
  int? maxLength,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        final c = ctx.palette;
        return CupertinoAlertDialog(
          title: Text(title, style: _family(AppTypography.headline)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message, style: _family(AppTypography.footnote)),
                const SizedBox(height: AppSpacing.sm),
              ] else
                const SizedBox(height: AppSpacing.sm),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                placeholder: placeholder,
                minLines: maxLines > 1 ? 3 : 1,
                maxLines: maxLines,
                maxLength: maxLength,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                style: AppTypography.subheadline.copyWith(color: c.label),
                placeholderStyle:
                    AppTypography.subheadline.copyWith(color: c.placeholder),
                cursorColor: c.accent,
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                      color: c.separator, width: AppSpacing.hairline),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              textStyle: _family(AppTypography.body),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(cancelLabel ?? ctx.tr('إلغاء', 'Cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              textStyle: _family(AppTypography.headline),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(ctx).pop(controller.text);
              },
              child: Text(confirmLabel ?? ctx.tr('حفظ', 'Save')),
            ),
          ],
        );
      },
    );
  } finally {
    // The route's exit animation still reads the controller for a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}

// ─── Action sheet ──────────────────────────────────────────────────────────

class AppSheetAction<T> {
  const AppSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
  final bool isDefault;
}

/// iOS action sheet. Returns the chosen action's value, null on cancel.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String? cancelLabel,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) {
      final c = ctx.palette;
      Widget label(AppSheetAction<T> a) {
        final color = a.isDestructive ? c.destructive : c.accent;
        final text = Text(
          a.label,
          style: _family(
              a.isDefault ? AppTypography.headline : AppTypography.body),
        );
        if (a.icon == null) return text;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, size: 21, color: color),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(child: text),
          ],
        );
      }

      return CupertinoActionSheet(
        title: title == null
            ? null
            : Text(title, style: _family(AppTypography.footnote)),
        message: message == null
            ? null
            : Text(message, style: _family(AppTypography.footnote)),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.isDestructive,
              isDefaultAction: a.isDefault,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(ctx).pop(a.value);
              },
              child: label(a),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            cancelLabel ?? ctx.tr('إلغاء', 'Cancel'),
            style: _family(AppTypography.headline),
          ),
        ),
      );
    },
  );
}

// ─── Sheets ────────────────────────────────────────────────────────────────

/// Full-height card sheet (iOS page sheet; the page behind scales back).
/// Drag down or tap "Done" to dismiss. [builder] must hand [controller] to its
/// main scroll view so dragging hands off between scrolling and dismissing.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, ScrollController controller)
      builder,
  String? doneLabel,
  Widget? leading,
}) {
  return showCupertinoSheet<T>(
    context: context,
    scrollableBuilder: (ctx, controller) => _AppSheetPage(
      title: title,
      doneLabel: doneLabel,
      leading: leading,
      child: builder(ctx, controller),
    ),
  );
}

class _AppSheetPage extends StatelessWidget {
  const _AppSheetPage({
    required this.title,
    required this.child,
    this.doneLabel,
    this.leading,
  });

  final String title;
  final String? doneLabel;
  final Widget? leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Lets any Material widget inside the sheet find an ancestor.
      type: MaterialType.transparency,
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          transitionBetweenRoutes: false,
          leading: leading,
          middle: Text(title),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(AppSpacing.minTouchTarget),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              doneLabel ?? context.tr('تم', 'Done'),
              style: AppTypography.headline
                  .copyWith(color: context.palette.accent),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Compact sheet that hugs its content (option pickers, short forms).
/// Slides up from the bottom; tap outside or the close button to dismiss.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => AppBottomSheetFrame(title: title, child: builder(ctx)),
  );
}

/// The surface of [showAppBottomSheet]: rounded top corners, title row with a
/// close button, keyboard- and home-indicator-aware bottom padding.
class AppBottomSheetFrame extends StatelessWidget {
  const AppBottomSheetFrame({super.key, required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: c.groupedBackground,
            shape: const RoundedSuperellipseBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom + AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? '',
                            style:
                                AppTypography.headline.copyWith(color: c.label),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: context.tr('إغلاق', 'Close'),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize:
                                const Size.square(AppSpacing.minTouchTarget),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 28,
                              color: c.tertiaryLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(child: SingleChildScrollView(child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pickers ───────────────────────────────────────────────────────────────

/// Wheel picker in a bottom popup with Cancel / Done. Returns the chosen item.
Future<T?> showAppPicker<T>(
  BuildContext context, {
  required List<T> items,
  required T selected,
  required String Function(T item) labelOf,
  String? title,
}) {
  var index = items.indexOf(selected).clamp(0, items.length - 1);
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => _PickerFrame(
      title: title,
      onDone: () => Navigator.of(ctx).pop(items[index]),
      child: CupertinoPicker(
        itemExtent: 36,
        scrollController: FixedExtentScrollController(initialItem: index),
        onSelectedItemChanged: (i) {
          index = i;
          // CupertinoPicker already clicks on iOS.
          if (defaultTargetPlatform != TargetPlatform.iOS) {
            HapticFeedback.selectionClick();
          }
        },
        children: [
          for (final item in items) Center(child: Text(labelOf(item))),
        ],
      ),
    ),
  );
}

/// Date / time wheel in a bottom popup with Cancel / Done.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initial,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
  DateTime? minimum,
  DateTime? maximum,
  String? title,
}) {
  var value = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => _PickerFrame(
      title: title,
      onDone: () => Navigator.of(ctx).pop(value),
      child: CupertinoDatePicker(
        mode: mode,
        initialDateTime: initial,
        minimumDate: minimum,
        maximumDate: maximum,
        onDateTimeChanged: (d) {
          value = d;
          if (defaultTargetPlatform != TargetPlatform.iOS) {
            HapticFeedback.selectionClick();
          }
        },
      ),
    ),
  );
}

class _PickerFrame extends StatelessWidget {
  const _PickerFrame({required this.child, required this.onDone, this.title});

  final Widget child;
  final VoidCallback onDone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
      decoration: ShapeDecoration(
        color: c.secondaryGroupedBackground,
        shape: const RoundedSuperellipseBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: c.separator, width: AppSpacing.hairline),
              ),
            ),
            child: Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('إلغاء', 'Cancel'),
                    style: AppTypography.body.copyWith(color: c.accent),
                  ),
                ),
                Expanded(
                  child: Text(
                    title ?? '',
                    textAlign: TextAlign.center,
                    style: AppTypography.headline.copyWith(color: c.label),
                  ),
                ),
                CupertinoButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDone();
                  },
                  child: Text(
                    context.tr('تم', 'Done'),
                    style: AppTypography.headline.copyWith(color: c.accent),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 216, child: child),
        ],
      ),
    );
  }
}

// ─── Toast ─────────────────────────────────────────────────────────────────

/// Transient capsule message near the bottom of the screen (iOS has no
/// snackbar; this follows the system HUD look). One at a time; an optional
/// action (e.g. "Undo") keeps it up a little longer.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    // Measure from the caller: inside the tab shell this already includes
    // the tab bar and mini-player.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        bottomInset: bottomInset,
        duration: duration ??
            (actionLabel != null
                ? const Duration(seconds: 4)
                : const Duration(milliseconds: 2500)),
        onFinished: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.bottomInset,
    required this.duration,
    required this.onFinished,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double bottomInset;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: AppMotion.fast);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final curved = CurvedAnimation(parent: _anim, curve: AppMotion.curve);
    final palette = context.palette;

    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: AppSpacing.screenMargin,
      end: AppSpacing.screenMargin,
      bottom: widget.bottomInset + AppSpacing.ms,
      child: SafeArea(
        top: false,
        bottom: widget.bottomInset == 0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(0, reduceMotion ? 0 : 0.4),
                  end: Offset.zero,
                ).animate(curved),
                child: Semantics(
                  liveRegion: true,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: palette.resolve(AppColors.toastBackground),
                      shape: AppRadius.continuous(AppRadius.large),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        widget.actionLabel == null
                            ? AppSpacing.md
                            : AppSpacing.xs,
                        AppSpacing.xs,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            minHeight: AppSpacing.minTouchTarget),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon,
                                  size: 20, color: AppColors.toastLabel),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Flexible(
                              child: Text(
                                widget.message,
                                style: AppTypography.subheadline
                                    .copyWith(color: AppColors.toastLabel),
                              ),
                            ),
                            if (widget.actionLabel != null)
                              CupertinoButton(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: AppSpacing.ms,
                                ),
                                minimumSize: const Size.square(
                                    AppSpacing.minTouchTarget),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  widget.onAction?.call();
                                  _hide();
                                },
                                child: Text(
                                  widget.actionLabel!,
                                  style: AppTypography.subheadline
                                      .weight(FontWeight.w600)
                                      .copyWith(color: AppColors.toastAction),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
