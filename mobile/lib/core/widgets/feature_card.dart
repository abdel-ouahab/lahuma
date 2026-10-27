import '../design/design.dart';

/// Shortcut tile: a Settings-style coloured glyph tile over a neutral card.
/// The colour lives only in the glyph; the card itself stays neutral. Its
/// height follows its text, so it never clips under large Dynamic Type.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.onTap,
    this.badge,
    this.badgeLabel,
  });

  final String title;
  final IconData icon;

  /// A design token, e.g. [AppColors.tilePurple].
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Count shown as a notification badge in the top trailing corner (top
  /// left in Arabic), including 0; null shows no badge.
  final int? badge;

  /// Spoken description of [badge].
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AppCard(
      onTap: onTap,
      semanticLabel: subtitle == null ? title : '$title، $subtitle',
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(icon: icon, color: iconColor, size: 32),
              const Spacer(),
              if (badge != null)
                AppBadge(
                    count: badge!, semanticLabel: badgeLabel, showZero: true),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          Text(
            title,
            style: AppTypography.headline.copyWith(color: c.label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
