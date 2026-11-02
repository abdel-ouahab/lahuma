import 'package:intl/intl.dart' show NumberFormat;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern('en');

/// "98°" — whole degrees, Latin digits as elsewhere in the app.
String degrees(double value) => '${value.round() % 360}°';

/// "2,750" — whole km with grouping.
String kilometres(double value) => _grouped.format(value.round());

/// "القبلة على 98° من الشمال" / "Qibla at 98° from north".
String qiblaFromNorth(BuildContext context, double bearing) => context.tr(
    'القبلة على ${ltr(degrees(bearing))} من الشمال',
    'Qibla at ${degrees(bearing)} from north');

/// Cardinal labels, clockwise from north.
List<String> cardinals(BuildContext context) => context.isArabic
    ? const ['شمال', 'شرق', 'جنوب', 'غرب']
    : const ['N', 'E', 'S', 'W'];
