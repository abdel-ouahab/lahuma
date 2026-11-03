import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../qibla_providers.dart';
import 'qibla_labels.dart';

/// Qibla angle from north · distance to Makkah · where it's measured from.
class QiblaInfoCard extends StatelessWidget {
  const QiblaInfoCard({super.key, required this.info});

  final QiblaInfo info;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    Widget divider() => Container(
          width: AppSpacing.hairline,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          color: c.separator,
        );

    return AppCard(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.ms),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Cell(
                label: context.tr('زاوية القبلة', 'Qibla angle'),
                value: degrees(info.bearing),
                unit: context.tr('من الشمال', 'from north'),
                ltrValue: true,
              ),
            ),
            divider(),
            Expanded(
              child: _Cell(
                label: context.tr('المسافة إلى مكة', 'To Makkah'),
                value: kilometres(info.distanceKm),
                unit: context.tr('كم', 'km'),
                ltrValue: true,
              ),
            ),
            divider(),
            Expanded(
              child: _Cell(
                label: context.tr('موقعك', 'Your location'),
                value: info.city.isEmpty
                    ? context.tr('غير معروف', 'Unknown')
                    : info.city,
                small: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    this.unit,
    this.ltrValue = false,
    this.small = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool ltrValue;

  /// A name rather than a number: smaller, and may wrap.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      container: true,
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTypography.caption1.copyWith(color: c.secondaryLabel),
            ),
            const SizedBox(height: 2),
            if (small)
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(color: c.label),
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  textDirection: ltrValue ? TextDirection.ltr : null,
                  maxLines: 1,
                  style: AppTypography.tabular(AppTypography.title2)
                      .copyWith(color: c.label),
                ),
              ),
            if (unit != null)
              Text(
                unit!,
                textAlign: TextAlign.center,
                style: AppTypography.caption1.copyWith(color: c.secondaryLabel),
              ),
          ],
        ),
      ),
    );
  }
}
