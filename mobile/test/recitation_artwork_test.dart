import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/design/widgets/app_ornaments.dart';
import 'package:lahuma/features/mp3quran/presentation/recitation_artwork.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget art,
      {bool reduceMotion = false}) {
    return tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
          textDirection: TextDirection.rtl, child: Center(child: art)),
    ));
  }

  double turns(WidgetTester tester) => tester
      .widget<RotationTransition>(find.descendant(
          of: find.byType(RecitationArtwork),
          matching: find.byType(RotationTransition)))
      .turns
      .value;

  bool hasShamsa(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((p) => p.painter is ShamsaPainter);

  testWidgets('the shamsa turns while playing and holds when paused',
      (tester) async {
    await pump(tester, const RecitationArtwork(size: 300, animate: true));
    await tester.pump(const Duration(seconds: 6));
    final moving = turns(tester);
    expect(moving, closeTo(6 / 120, 0.001));

    await pump(tester, const RecitationArtwork(size: 300));
    await tester.pump(const Duration(seconds: 6));
    expect(turns(tester), moving);

    await pump(tester, const RecitationArtwork(size: 300, animate: true));
    await tester.pump(const Duration(seconds: 6));
    expect(turns(tester), closeTo(moving + 6 / 120, 0.001));
  });

  testWidgets('Reduce Motion keeps it still', (tester) async {
    await pump(tester, const RecitationArtwork(size: 300, animate: true),
        reduceMotion: true);
    await tester.pump(const Duration(seconds: 6));
    expect(turns(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a small tile shows only the wordmark', (tester) async {
    await pump(tester, const RecitationArtwork(size: 40, animate: true));
    expect(hasShamsa(tester), isFalse);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await pump(tester, const RecitationArtwork(size: 112, radius: 22));
    expect(hasShamsa(tester), isTrue);
  });
}
