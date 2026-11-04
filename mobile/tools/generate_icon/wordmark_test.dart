// Renders the Ihsan wordmark (إحسان and "Ihsan" in Aref Ruqaa Bold, OFL) to
// white-on-transparent PNGs that generate.py colours and lays out. Dart is
// used because it shapes Arabic; Pillow on this machine cannot.
//
//     flutter test tools/generate_icon/wordmark_test.dart
//
// Run from mobile/, then run generate.py.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'tools/generate_icon';
const _family = 'ArefRuqaa';

void main() {
  testWidgets('renders the wordmark', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('$_dir/ArefRuqaa-Bold.ttf').readAsBytesSync();
      await (FontLoader(_family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    });
    await tester.binding.setSurfaceSize(const Size(4200, 2400));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (text, file) in [
      ('إحسان', 'wordmark_ar.png'),
      ('Ihsan', 'wordmark_en.png'),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 4200,
              height: 2400,
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: _family,
                    fontSize: 1100,
                    height: 1.8,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/$file').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
