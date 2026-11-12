import '../design/design.dart';

/// Shortcut washed in its own colour: the glyph in that colour at the top,
/// title and a short caption at the bottom. [wide] lays it out as one row
/// instead. Its height follows its text, so it never clips under large
/// Dynamic Type; put tiles in an `IntrinsicHeight` row to line them up.
///
/// With a [scene] the tile is a small painted picture of its subject in the
/// prayer-times hero's grammar (sky in its tone, silhouette, white type)
/// instead of a flat wash. A [footer] on a scene should be drawn in white.
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
    this.scene,
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

  /// Painted behind the tile; null keeps the flat wash.
  final TileScene? scene;

  /// White on scenes, which are dark pictures in both themes.
  static const Color onScene = CupertinoColors.white;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final tone = c.resolve(color);
    final scene = this.scene;
    // Scenes are pictures: the same light-theme tone in both themes.
    final sceneTone = color is CupertinoDynamicColor
        ? (color as CupertinoDynamicColor).color
        : color;
    final glyph =
        Icon(icon, size: 24, color: scene == null ? tone : AppColors.skyStar);
    final titleColor = scene == null ? c.label : onScene;
    final captionColor =
        scene == null ? c.secondaryLabel : onScene.withValues(alpha: 0.82);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.subheadline
              .copyWith(color: titleColor, fontWeight: FontWeight.w600),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption1.copyWith(color: captionColor),
          ),
      ],
    );
    return AppCard(
      onTap: onTap,
      semanticLabel: caption == null ? title : '$title، $caption',
      color: scene == null
          ? Color.alphaBlend(tone.withValues(alpha: c.isDark ? 0.16 : 0.09),
              c.secondaryGroupedBackground)
          : TileScenePainter.baseFor(sceneTone),
      borderColor: scene == null
          ? tone.withValues(alpha: c.isDark ? 0.3 : 0.2)
          : AppColors.gold.color.withValues(alpha: c.isDark ? 0.35 : 0.5),
      ornament: scene == null
          ? null
          : TileScenePainter(
              scene: scene,
              tone: sceneTone,
              textDirection: Directionality.of(context),
            ),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      child: wide
          ? Row(
              children: [
                glyph,
                const SizedBox(width: AppSpacing.ms),
                Expanded(child: text),
                AppDirectionalIcon(CupertinoIcons.chevron_forward,
                    size: 16,
                    color: scene == null
                        ? c.tertiaryLabel
                        : onScene.withValues(alpha: 0.7)),
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
