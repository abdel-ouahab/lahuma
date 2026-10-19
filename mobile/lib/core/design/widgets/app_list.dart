import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import 'app_direction.dart';

const double _kLeadingSize = 30;
const double _kLeadingGap = 12;

/// Inset-grouped list section (iOS Settings style): rounded group on the
/// grouped background, hairline separators aligned with the titles.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.hasLeading = false,
    this.margin = const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screenMargin,
      0,
      AppSpacing.screenMargin,
      AppSpacing.sm,
    ),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  /// True when the rows show a leading icon tile; separators then start at
  /// the title, as on iOS.
  final bool hasLeading;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final caption = AppTypography.footnote.copyWith(color: c.secondaryLabel);
    return CupertinoListSection.insetGrouped(
      backgroundColor: CupertinoColors.transparent,
      margin: margin,
      dividerMargin: 0,
      additionalDividerMargin: hasLeading
          ? AppSpacing.md + _kLeadingSize + _kLeadingGap
          : AppSpacing.md,
      header: header == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: Text(header!, style: caption),
            ),
      footer: footer == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: Text(footer!, style: caption),
            ),
      children: children,
    );
  }
}

/// One row of an [AppListSection].
///
/// Accessories: [value] (secondary text at the end), [chevron] (disclosure,
/// mirrored in RTL — on by default when tappable), or any [trailing] widget
/// (e.g. an [AppSwitch]). Titles wrap to two lines so large text never clips.
class AppListTile extends StatefulWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron,
    this.destructive = false,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;

  /// Usually an `AppIconTile`; sized to 30 × 30.
  final Widget? leading;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to `onTap != null && trailing == null`.
  final bool? chevron;

  /// Red title, for "Sign out" / "Delete" rows.
  final bool destructive;
  final TextStyle? titleStyle;

  @override
  State<AppListTile> createState() => _AppListTileState();
}

class _AppListTileState extends State<AppListTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final showChevron =
        widget.chevron ?? (widget.onTap != null && widget.trailing == null);
    final titleStyle = widget.titleStyle ??
        AppTypography.body
            .copyWith(color: widget.destructive ? c.destructive : c.label);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.ms - 1,
          AppSpacing.md,
          AppSpacing.ms - 1,
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              SizedBox.square(dimension: _kLeadingSize, child: widget.leading),
              const SizedBox(width: _kLeadingGap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTypography.footnote
                          .copyWith(color: c.secondaryLabel),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.value != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  widget.value!,
                  style: AppTypography.body.copyWith(color: c.secondaryLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
            if (widget.trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              widget.trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: AppSpacing.xs + 2),
              AppDirectionalIcon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: c.tertiaryLabel,
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.onTap == null) return row;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: ColoredBox(
          // iOS rows highlight grey while held instead of rippling.
          color: _pressed
              ? c.resolve(CupertinoColors.systemGrey4)
              : CupertinoColors.transparent,
          child: row,
        ),
      ),
    );
  }
}

/// iOS switch in the accent colour, with a selection haptic.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.accent,
        onChanged: onChanged == null
            ? null
            : (v) {
                HapticFeedback.selectionClick();
                onChanged!(v);
              },
      );
}
