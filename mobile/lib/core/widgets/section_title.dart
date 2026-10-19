import '../design/design.dart';

/// Section title with optional trailing action (iOS "See All" style).
class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, this.trailing, this.onTrailingTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  style: AppTypography.title3.copyWith(color: c.label)),
            ),
          ),
          if (trailing != null)
            AppButton.plain(
                label: trailing!, small: true, onPressed: onTrailingTap),
        ],
      ),
    );
  }
}
