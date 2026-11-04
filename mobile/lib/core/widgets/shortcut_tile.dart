import '../design/design.dart';

/// Shortcut washed in its own colour: the glyph in that colour at the top,
/// title and a short caption at the bottom. [wide] lays it out as one row
/// instead. Its height follows its text, so it never clips under large
/// Dynamic Type; put tiles in an `IntrinsicHeight` row to line them up.
class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.caption,
    this.footer,
    this.wide = false,
  });

  final String title;
  final IconData icon;

  /// A design token, e.g. [AppColors.tileBlue].
  final Color color;
  final VoidCallback onTap;
  final String? caption;

  /// Under the caption on a tall tile, e.g. a [SegmentBar].
  final Widget? footer;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final tone = c.resolve(color);
    final glyph = Icon(icon, size: 24, color: tone);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.subheadline
              .copyWith(color: c.label, fontWeight: FontWeight.w600),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption1.copyWith(color: c.secondaryLabel),
          ),
      ],
    );
    return AppCard(
      onTap: onTap,
      semanticLabel: caption == null ? title : '$title، $caption',
      color: Color.alphaBlend(tone.withValues(alpha: c.isDark ? 0.16 : 0.09),
          c.secondaryGroupedBackground),
      borderColor: tone.withValues(alpha: c.isDark ? 0.3 : 0.2),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      child: wide
          ? Row(
              children: [
                glyph,
                const SizedBox(width: AppSpacing.ms),
                Expanded(child: text),
                AppDirectionalIcon(CupertinoIcons.chevron_forward,
                    size: 16, color: c.tertiaryLabel),
              ],
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  glyph,
                  const SizedBox(height: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      text,
                      if (footer != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        footer!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
