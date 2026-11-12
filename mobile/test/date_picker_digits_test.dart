import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/design/widgets/app_overlays.dart';

void main() {
  testWidgets('time wheel uses 0-9 digits with Arabic words', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(CupertinoApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    showAppDatePicker(ctx,
        initial: DateTime(2026, 11, 11, 21, 47),
        mode: CupertinoDatePickerMode.time);
    await tester.pumpAndSettle();

    expect(find.text('47'), findsWidgets);
    expect(find.text('٤٧'), findsNothing);
    expect(find.text('م'), findsWidgets);
  });
}
