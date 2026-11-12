// Responsive layout harness: pumps a screen of the real app (its router,
// theme, shell and tab bar) at the phone sizes below and fails on any
// overflow or layout exception.
//
//   flutter test test/responsive                              # worst cases
//   flutter test test/responsive --dart-define=FULL=true      # whole matrix
//   flutter test test/responsive --plain-name home            # one screen
//   ... --dart-define=SHOTS=true                              # + screenshots
//
// The whole matrix: 7 sizes x portrait/landscape x Arabic/English x text
// scale 1.0/1.3/2.0 x light/dark, and again with the keyboard up on screens
// with a text field. Without FULL, only the cells that break first (the
// smallest phone at 2.0, landscape, the keyboard, dark) run, so the normal
// `flutter test` stays quick. QUICK=true keeps three sizes; SMOKE=true three
// cells.
//
// Screenshots go to test/responsive/_screenshots/<screen>/ (git-ignored),
// FAIL_ ones for every failing cell; a JSON summary per screen to
// test/responsive/_report/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Checkbox, IconButton, InkResponse, Switch;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/design/design.dart' show AppMiniPlayerBar, AppTabBar;
import 'package:lahuma/core/router/app_router.dart';
import 'package:lahuma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const bool kShots = bool.fromEnvironment('SHOTS');
const bool kQuick = bool.fromEnvironment('QUICK');
const bool kSmoke = bool.fromEnvironment('SMOKE');
const bool kFull = bool.fromEnvironment('FULL');

/// A phone or tablet: its portrait size and safe areas, in logical pixels.
class Device {
  const Device(this.id, this.size,
      {required this.portrait, required this.landscape});

  final String id;
  final Size size;
  final EdgeInsets portrait;
  final EdgeInsets landscape;
}

const _android = EdgeInsets.only(top: 24, bottom: 24);
const _androidLand = EdgeInsets.only(top: 24, bottom: 16);
const _notch = EdgeInsets.only(top: 47, bottom: 34);
const _notchLand = EdgeInsets.only(left: 47, right: 47, bottom: 21);
const _island = EdgeInsets.only(top: 59, bottom: 34);
const _islandLand = EdgeInsets.only(left: 59, right: 59, bottom: 21);

const devices = <Device>[
  Device('320x568', Size(320, 568), portrait: _android, landscape: _androidLand),
  Device('375x667', Size(375, 667),
      portrait: EdgeInsets.only(top: 20), landscape: EdgeInsets.zero),
  Device('360x800', Size(360, 800), portrait: _android, landscape: _androidLand),
  Device('390x844', Size(390, 844), portrait: _notch, landscape: _notchLand),
  Device('412x915', Size(412, 915), portrait: _android, landscape: _androidLand),
  Device('430x932', Size(430, 932), portrait: _island, landscape: _islandLand),
  Device('768x1024', Size(768, 1024),
      portrait: EdgeInsets.only(top: 24, bottom: 20),
      landscape: EdgeInsets.only(top: 24, bottom: 20)),
];

const textScales = <double>[1.0, 1.3, 2.0];

/// One cell of the matrix.
class Combo {
  const Combo({
    required this.device,
    required this.landscape,
    required this.scale,
    required this.locale,
    required this.dark,
    this.keyboard = false,
  });

  final Device device;
  final bool landscape;
  final double scale;
  final String locale;
  final bool dark;
  final bool keyboard;

  Size get size => landscape ? device.size.flipped : device.size;
  EdgeInsets get safeArea => landscape ? device.landscape : device.portrait;

  /// A soft keyboard's height: about 40% of a portrait screen, more of a
  /// landscape one (with its suggestion strip).
  double get keyboardHeight =>
      keyboard ? (landscape ? size.height * 0.58 : size.height * 0.42) : 0;

  String get id => '${device.id}_${landscape ? 'land' : 'port'}_$locale'
      '_${dark ? 'dark' : 'light'}_x$scale${keyboard ? '_kb' : ''}';

  Map<String, Object> toJson() => {
        'device': device.id,
        'orientation': landscape ? 'landscape' : 'portrait',
        'locale': locale,
        'theme': dark ? 'dark' : 'light',
        'textScale': scale,
        'keyboard': keyboard,
      };
}

/// Which matrix cells also get a PNG (with SHOTS=true). Failing cells
/// always do.
bool _reviewShot(Combo c) {
  final d = c.device.id;
  if (c.keyboard) {
    return c.locale == 'ar' &&
        !c.dark &&
        c.scale == 1.0 &&
        (d == '320x568' || (d == '390x844' && c.landscape));
  }
  if (c.dark) {
    return c.locale == 'ar' && c.scale == 1.0 && d == '390x844' && !c.landscape;
  }
  if (c.scale == 1.0) {
    if (c.locale == 'ar') {
      return !c.landscape ||
          d == '320x568' ||
          d == '390x844' ||
          d == '768x1024';
    }
    return !c.landscape && (d == '320x568' || d == '390x844');
  }
  if (c.scale == 2.0) {
    if (c.locale == 'ar') {
      return d == '320x568' && !c.landscape ||
          d == '390x844';
    }
    return d == '320x568' && !c.landscape;
  }
  return false;
}

/// A screen (or a sheet/dialog over one) to check.
class ScreenCase {
  const ScreenCase(
    this.id, {
    required this.route,
    this.overrides = const [],
    this.prefs = const {},
    this.open,
    this.hasInput = false,
    this.settleFrames = 8,
    this.skipLandscape = false,
    this.setup,
    this.routeFor,
  });

  /// Folder name for its screenshots and report, and the test's name.
  final String id;

  /// Where the router goes before anything else.
  final String route;
  final List<Override> overrides;

  /// SharedPreferences on top of the defaults (onboarding seen, language,
  /// theme).
  final Map<String, Object> prefs;

  /// Opens a sheet or dialog once the route is up, if this case is one.
  final Future<void> Function(WidgetTester tester)? open;

  /// Also checked with the keyboard up.
  final bool hasInput;
  final int settleFrames;

  /// For screens that can't be reached in landscape at all.
  final bool skipLandscape;

  /// Seeds state through the app's own notifiers before the app starts
  /// (see [settle]).
  final Future<void> Function(WidgetTester tester, ProviderContainer container)?
      setup;

  /// The route, when it depends on what [setup] created.
  final String Function(ProviderContainer container)? routeFor;
}

/// Pumps until [future] completes: SharedPreferences mocks and the app's
/// notifiers finish in microtasks, so this runs them in the test's fake
/// zone (runAsync would deadlock on them).
Future<T> settle<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  Object? error;
  future.then((v) {
    value = v;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  });
  for (var i = 0; !done && i < 500; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  if (error != null) throw error!;
  if (!done) throw StateError('setup did not finish');
  return value;
}

/// A layout problem in one cell.
class Problem {
  Problem(this.combo, this.summary, this.where, this.library);

  final Combo combo;
  final String summary;
  final String where;
  final String library;
}

final _shotKey = GlobalKey();
bool _fontsLoaded = false;
final _testDir = Directory('test/responsive');

/// The app's Google fonts (the exact files google_fonts downloads, saved
/// under the names its device cache uses) and the icon fonts. Also points
/// path_provider at that folder, so google_fonts finds them there as on a
/// phone that has them cached.
Future<void> loadFonts(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final fontsDir = Directory('${_testDir.path}/fonts').absolute;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => fontsDir.path);
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  await tester.runAsync(() async {
    Hive.init(Directory.systemTemp.createTempSync('lahuma_responsive').path);
    await Hive.openBox<String>(StorageKeys.bookmarksBox);
    await Hive.openBox<String>(StorageKeys.quranCacheBox);
    final byFamily = <String, List<File>>{};
    for (final f in fontsDir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.ttf')) continue;
      final parts = name.split('_'); // Cairo_700_<hash>.ttf
      byFamily.putIfAbsent('${parts[0]}_${parts[1]}', () => []).add(f);
      byFamily.putIfAbsent(parts[0], () => []).add(f);
    }
    for (final e in byFamily.entries) {
      final loader = FontLoader(e.key);
      for (final f in e.value) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await loader.load();
    }
    final manifest = json.decode(
            await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      // The Mushaf's 604 page fonts: only the first pages are ever shown.
      final page = RegExp(r'QCF_P(\d{3})$').firstMatch(family);
      if (page != null && int.parse(page.group(1)!) > 5) continue;
      final loader = FontLoader(family);
      for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        final data = await rootBundle.load(font['asset'] as String);
        loader.addFont(Future.value(_unwoff(data)));
      }
      await loader.load();
    }
  });
}

/// The test engine reads TrueType/OpenType only; qcf_quran ships WOFF 1
/// (zlib-compressed tables). Unpacks it back into the font it wraps.
ByteData _unwoff(ByteData woff) {
  if (woff.lengthInBytes < 44 || woff.getUint32(0) != 0x774F4646) return woff;
  final numTables = woff.getUint16(12);
  final tables = <({int tag, int checksum, Uint8List data})>[];
  for (var i = 0; i < numTables; i++) {
    final at = 44 + i * 20;
    final offset = woff.getUint32(at + 4);
    final compLength = woff.getUint32(at + 8);
    final origLength = woff.getUint32(at + 12);
    final raw = woff.buffer.asUint8List(woff.offsetInBytes + offset, compLength);
    tables.add((
      tag: woff.getUint32(at),
      checksum: woff.getUint32(at + 16),
      data: compLength < origLength
          ? Uint8List.fromList(zlib.decode(raw))
          : Uint8List.fromList(raw),
    ));
  }
  var pow2 = 1, log2 = 0;
  while (pow2 * 2 <= numTables) {
    pow2 *= 2;
    log2++;
  }
  var size = 12 + 16 * numTables;
  for (final t in tables) {
    size += (t.data.length + 3) & ~3;
  }
  final out = ByteData(size);
  out
    ..setUint32(0, woff.getUint32(4))
    ..setUint16(4, numTables)
    ..setUint16(6, pow2 * 16)
    ..setUint16(8, log2)
    ..setUint16(10, numTables * 16 - pow2 * 16);
  var dataAt = 12 + 16 * numTables;
  final bytes = out.buffer.asUint8List();
  for (var i = 0; i < tables.length; i++) {
    final t = tables[i];
    out
      ..setUint32(12 + i * 16, t.tag)
      ..setUint32(16 + i * 16, t.checksum)
      ..setUint32(20 + i * 16, dataAt)
      ..setUint32(24 + i * 16, t.data.length);
    bytes.setRange(dataAt, dataAt + t.data.length, t.data);
    dataAt += (t.data.length + 3) & ~3;
  }
  return out;
}

/// The cells that break first, for the everyday run.
List<Combo> _coreCells(ScreenCase c) {
  final small = devices[0], se = devices[1], phone = devices[3];
  final tablet = devices[6];
  Combo cell(Device d, String locale, double scale,
          {bool landscape = false, bool dark = false, bool keyboard = false}) =>
      Combo(
          device: d,
          landscape: landscape,
          scale: scale,
          locale: locale,
          dark: dark,
          keyboard: keyboard);
  return [
    cell(small, 'ar', 2),
    cell(se, 'ar', 1.3),
    if (!c.skipLandscape) ...[
      cell(small, 'ar', 1, landscape: true),
      cell(tablet, 'ar', 1, landscape: true),
    ],
    if (c.hasInput) cell(small, 'ar', 1, keyboard: true),
    cell(small, 'en', 2),
    if (!c.skipLandscape) cell(small, 'en', 2, landscape: true),
    if (c.hasInput && !c.skipLandscape)
      cell(phone, 'en', 1, landscape: true, keyboard: true),
    cell(phone, 'ar', 1, dark: true),
  ];
}

/// Every cell of the matrix for [c] (see the top of this file).
List<Combo> matrix(ScreenCase c) {
  if (!kFull && !kQuick && !kSmoke) return _coreCells(c);
  if (kSmoke) {
    final phone = devices[3], small = devices[0];
    return [
      Combo(device: phone, landscape: false, scale: 1, locale: 'ar', dark: false),
      Combo(device: small, landscape: false, scale: 2, locale: 'en', dark: false),
      if (!c.skipLandscape)
        Combo(device: small, landscape: true, scale: 1, locale: 'ar', dark: false),
      if (c.hasInput)
        Combo(
            device: small,
            landscape: false,
            scale: 1,
            locale: 'ar',
            dark: false,
            keyboard: true),
    ];
  }
  final sizes = kQuick
      ? devices.where((d) => const {'320x568', '390x844', '768x1024'}.contains(d.id))
      : devices;
  return [
    for (final locale in const ['ar', 'en'])
      for (final dark in const [false, true])
        for (final keyboard in [false, if (c.hasInput) true])
          for (final d in sizes)
            for (final landscape in [false, if (!c.skipLandscape) true])
              for (final scale in textScales)
                Combo(
                  device: d,
                  landscape: landscape,
                  scale: scale,
                  locale: locale,
                  dark: dark,
                  keyboard: keyboard,
                ),
  ];
}

/// Runs [c] through its matrix; returns the problems found.
Future<List<Problem>> runCase(WidgetTester tester, ScreenCase c) async {
  await loadFonts(tester);
  _warnings.clear();
  final shots = Directory('${_testDir.path}/_screenshots/${c.id}');
  if (kShots && shots.existsSync()) shots.deleteSync(recursive: true);
  final problems = <Problem>[];
  final cells = matrix(c);
  final groups = <String, List<Combo>>{};
  for (final combo in cells) {
    groups.putIfAbsent('${combo.locale}_${combo.dark}', () => []).add(combo);
  }
  var cellsRun = 0;
  for (final group in groups.values) {
    final first = group.first;
    SharedPreferences.setMockInitialValues({
      'onboarding_completed_v1': true,
      'settings.locale': first.locale == 'ar' ? 'arabic' : 'english',
      'settings.themeMode': first.dark ? 'dark' : 'light',
      ...c.prefs,
    });
    tester.platformDispatcher.platformBrightnessTestValue =
        first.dark ? Brightness.dark : Brightness.light;
    final container =
        ProviderContainer(overrides: [...baseOverrides, ...c.overrides]);
    _apply(tester, group.first);
    if (c.setup != null) await c.setup!(tester, container);
    final route = c.routeFor?.call(container) ?? c.route;

    // Boot like the app does: splash, then Home, then the route.
    final boot = await _capture(() async {
      await tester.pumpWidget(_app(container, 'boot'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final router = container.read(routerProvider);
      if (route != '/home') {
        router.go(route);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });
    // Only a broken boot counts here; Home's own layout is the home case's.
    problems.addAll(_toProblems(first, boot)
        .where((p) =>
            p.library == 'test' || (c.route == '/home' && c.open == null)));

    for (final combo in group) {
      _apply(tester, combo);
      final screenErrors = await _capture(() async {
        // A fresh widget tree each time: overflow is reported once per render
        // object. Unmount first: the router's navigator has a GlobalKey, so
        // a mere re-key would carry it (and any open sheet) over intact.
        await tester.pumpWidget(const SizedBox());
        final router = container.read(routerProvider);
        if (router.routerDelegate.currentConfiguration.uri.toString() !=
            route) {
          router.go(route);
        }
        await tester.pumpWidget(_app(container, combo.id));
        for (var i = 0; i < c.settleFrames; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
      // Routes already up before the overlay opens: an overlay case checks
      // the geometry of what opened, not of the screen behind it.
      final before = c.open == null ? null : _routesNow();
      final overlayErrors = c.open == null
          ? const <FlutterErrorDetails>[]
          : await _capture(() async {
              await c.open!(tester);
              for (var i = 0; i < 8; i++) {
                await tester.pump(const Duration(milliseconds: 60));
              }
            });
      final geometry = <Problem>[];
      final focusErrors = await _capture(() async {
        if (combo.keyboard) {
          geometry.addAll(await _keyboardCheck(tester, combo, before));
        }
      });
      // An overlay case answers for the overlay only: the screen behind it
      // has its own case. A screen that fails to build still counts.
      final found = [
        ..._toProblems(combo, [
          ...c.open == null
              ? screenErrors
              : screenErrors.where((e) => e.library == 'test'),
          ...overlayErrors,
          ...focusErrors,
        ]),
        ...geometry,
      ];
      if (kShots && (found.isNotEmpty || _reviewShot(combo))) {
        await _shot(tester, c.id, combo, failed: found.isNotEmpty);
      }
      final covered = <Problem>[];
      final coverErrors = await _capture(() async {
        covered.addAll(await _coverCheck(tester, combo, before));
      });
      covered.addAll(_toProblems(combo, coverErrors));
      if (kShots && covered.isNotEmpty) {
        await _shot(tester, c.id, combo, failed: true, suffix: '_end');
      }
      problems
        ..addAll(found)
        ..addAll(covered);
      cellsRun++;
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    container.dispose();
  }
  _resetView(tester);
  _writeReport(c, cellsRun, problems);
  return problems;
}

Widget _app(ProviderContainer container, String key) => RepaintBoundary(
      key: _shotKey,
      child: UncontrolledProviderScope(
        container: container,
        child: KeyedSubtree(key: ValueKey(key), child: const LahumaApp()),
      ),
    );

void _apply(WidgetTester tester, Combo c) {
  const dpr = 2.0;
  final view = tester.view;
  view.devicePixelRatio = dpr;
  view.physicalSize = c.size * dpr;
  final safe = c.safeArea;
  final kb = c.keyboardHeight;
  view.viewPadding = FakeViewPadding(
    left: safe.left * dpr,
    top: safe.top * dpr,
    right: safe.right * dpr,
    bottom: safe.bottom * dpr,
  );
  // The keyboard covers the home-indicator inset.
  view.padding = FakeViewPadding(
    left: safe.left * dpr,
    top: safe.top * dpr,
    right: safe.right * dpr,
    bottom: kb > 0 ? 0 : safe.bottom * dpr,
  );
  view.viewInsets = FakeViewPadding(bottom: kb * dpr);
  tester.platformDispatcher.textScaleFactorTestValue = c.scale;
}

void _resetView(WidgetTester tester) {
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  tester.platformDispatcher.clearPlatformBrightnessTestValue();
}

/// Runs [body] with every Flutter error collected instead of failing.
Future<List<FlutterErrorDetails>> _capture(Future<void> Function() body) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } catch (e, s) {
    errors.add(FlutterErrorDetails(exception: e, stack: s, library: 'test'));
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Errors that are about layout (or that broke a build); network images and
/// missing plugins in the test environment are not.
bool _isLayout(FlutterErrorDetails d) {
  final lib = d.library ?? '';
  final text = d.exceptionAsString();
  if (lib.contains('image resource service')) return false;
  if (text.contains('MissingPluginException')) return false;
  if (text.contains('HTTP request failed')) return false;
  // Async work outliving a matrix group's container, not a layout issue.
  if (text.contains('ProviderContainer that was already disposed')) {
    return false;
  }
  // just_audio closing its event subjects when a player is disposed while
  // its (missing, in tests) platform side is still starting up.
  if (text.contains('cannot close the subject while items are being added')) {
    return false;
  }
  // An async callback finishing after its screen closed (the matrix closes
  // screens far faster than a person): an app lifecycle bug, reported as a
  // warning rather than a layout failure.
  if (text.contains('after the widget was disposed')) return false;
  return true;
}

final _libLocation = RegExp(r'lib[/\\]([\w/\\]+\.dart):(\d+)');

/// Errors the run saw that are not about layout (a plugin missing in tests,
/// an app error), by message: reported, not failed on.
final _warnings = <String, String>{};

List<Problem> _toProblems(Combo combo, List<FlutterErrorDetails> errors) => [
      for (final e in errors.where((e) {
        if (_isLayout(e)) return true;
        final text = e.exceptionAsString().split('\n').first.trim();
        if (!text.contains('MissingPluginException') &&
            !text.contains('HTTP request failed')) {
          _warnings.putIfAbsent(text, () => _where(e));
        }
        return false;
      }))
        Problem(
          combo,
          e.exceptionAsString().split('\n').first.trim(),
          _where(e),
          e.library ?? '',
        ),
    ];

String _where(FlutterErrorDetails e) {
  final text = [
    e.toString(),
    e.stack?.toString() ?? '',
  ].join('\n');
  final m = _libLocation.firstMatch(text);
  return m == null ? '?' : '${m.group(1)!.replaceAll(r'\', '/')}:${m.group(2)}';
}

Future<void> _shot(WidgetTester tester, String caseId, Combo combo,
    {required bool failed, String suffix = ''}) async {
  final boundary =
      _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final dir = Directory('${_testDir.path}/_screenshots/$caseId');
  await tester.runAsync(() async {
    dir.createSync(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('${dir.path}/${failed ? 'FAIL_' : ''}${combo.id}$suffix.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ─── Geometry checks ───────────────────────────────────────────────────────

/// Anything a finger lands on.
Iterable<Element> _tappables() => find
    .byWidgetPredicate((w) =>
        w is CupertinoButton ||
        w is IconButton ||
        w is InkResponse ||
        w is CupertinoSwitch ||
        w is Switch ||
        w is CupertinoCheckbox ||
        w is Checkbox ||
        w is EditableText ||
        (w is GestureDetector && (w.onTap != null || w.onLongPress != null)))
    .evaluate();

Set<Route<dynamic>?> _routesNow() => {
      for (final e in _tappables()) ModalRoute.of(e),
      for (final e in find.byType(Scrollable).evaluate()) ModalRoute.of(e),
    };

/// Whether [e] belongs to what the case is about: the route on top for a
/// screen, whatever opened for an overlay (routes not in [before]).
bool _onTop(Element e, Set<Route<dynamic>?>? before) {
  final route = ModalRoute.of(e);
  if (before != null) return !before.contains(route);
  return route == null || route.isCurrent;
}

bool _inChrome(Element e) {
  var inside = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    inside = w is AppTabBar || w is AppMiniPlayerBar;
    return !inside;
  });
  return inside;
}

Rect? _rectOf(Element e) {
  final box = e.renderObject;
  if (box is! RenderBox || !box.attached || box.debugNeedsLayout) return null;
  if (!box.hasSize) return null;
  try {
    return box.localToGlobal(Offset.zero) & box.size;
  } on FlutterError {
    // An ancestor is mid-relayout (a frame is pending): not measurable now.
    return null;
  }
}

String _label(Element e) {
  String? text;
  void visit(Element child) {
    if (text != null) return;
    final w = child.widget;
    if (w is Text) {
      text = w.data ?? w.textSpan?.toPlainText();
    } else if (w is RichText) {
      text = w.text.toPlainText();
    }
    if (text == null) child.visitChildren(visit);
  }

  visit(e);
  final w = e.widget;
  final tip = w is IconButton ? w.tooltip : null;
  final name = (text ?? tip)?.trim().split('\n').first;
  return '${w.runtimeType}${name == null ? '' : ' "$name"'}';
}

/// With the keyboard up, focuses the lowest text field and checks it ends
/// up above the keyboard (the field scrolls into view, or its sheet lifts).
Future<List<Problem>> _keyboardCheck(
    WidgetTester tester, Combo combo, Set<Route<dynamic>?>? before) async {
  final fields = find
      .byType(EditableText)
      .evaluate()
      .where((e) => _onTop(e, before) && _rectOf(e) != null)
      .toList();
  if (fields.isEmpty) return const [];
  fields.sort((a, b) => _rectOf(a)!.bottom.compareTo(_rectOf(b)!.bottom));
  final field = fields.last;
  ((field as StatefulElement).state as EditableTextState).requestKeyboard();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final rect = _rectOf(field);
  if (rect == null) return const [];
  final keyboardTop = combo.size.height - combo.keyboardHeight;
  if (rect.bottom <= keyboardTop + 1 && rect.top >= -1) return const [];
  return [
    Problem(combo, 'Text field hidden behind the keyboard: ${_label(field)}',
        'keyboard', 'geometry'),
  ];
}

/// Scrolls everything on top to its end, then looks for controls whose
/// middle sits under the tab bar, the mini player or the keyboard: if they
/// are there at the end of the scroll, no one can reach them.
Future<List<Problem>> _coverCheck(
    WidgetTester tester, Combo combo, Set<Route<dynamic>?>? before) async {
  for (var pass = 0; pass < 2; pass++) {
    for (final e in find.byType(Scrollable).evaluate()) {
      if (!_onTop(e, before)) continue;
      final state = (e as StatefulElement).state as ScrollableState;
      if (state.axisDirection != AxisDirection.down &&
          state.axisDirection != AxisDirection.up) {
        continue;
      }
      // A wheel picker moves its value when scrolled; leave it be.
      if (state.widget.physics is FixedExtentScrollPhysics) continue;
      final p = state.position;
      if (p.hasContentDimensions && p.maxScrollExtent > p.pixels) {
        p.jumpTo(p.maxScrollExtent);
      }
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  final size = combo.size;
  final covers = <(String, Rect)>[
    if (combo.keyboard)
      ('the keyboard',
          Rect.fromLTRB(0, size.height - combo.keyboardHeight, size.width,
              size.height)),
    // Overlays sit above the shell's chrome.
    if (before == null) ...[
      for (final e in find.byType(AppTabBar).evaluate())
        if (_rectOf(e) case final r?) ('the tab bar', r),
      for (final e in find.byType(AppMiniPlayerBar).evaluate())
        if (_rectOf(e) case final r?) ('the mini player', r),
    ],
  ];
  if (covers.isEmpty) return const [];

  final problems = <Problem>[];
  final seen = <RenderObject>{};
  for (final e in _tappables()) {
    if (!_onTop(e, before) || _inChrome(e)) continue;
    final r = _rectOf(e);
    if (r == null || r.isEmpty || !seen.add(e.renderObject!)) continue;
    final mid = r.center;
    if (mid.dx < 0 || mid.dx > size.width || mid.dy < 0) continue;
    for (final (name, cover) in covers) {
      if (cover.contains(mid)) {
        problems.add(Problem(
            combo, 'Control under $name: ${_label(e)}', 'covered', 'geometry'));
        break;
      }
    }
  }
  return problems;
}

void _writeReport(ScreenCase c, int cells, List<Problem> problems) {
  final dir = Directory('${_testDir.path}/_report')..createSync(recursive: true);
  File('${dir.path}/${c.id}.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'screen': c.id,
      'route': c.route,
      'cells': cells,
      'failures': problems.length,
      'warnings': [
        for (final w in _warnings.entries) {'error': w.key, 'where': w.value},
      ],
      'problems': [
        for (final p in problems)
          {...p.combo.toJson(), 'error': p.summary, 'where': p.where},
      ],
    }),
  );
}

/// A readable digest: each distinct problem once, with the cells it hit.
String digest(List<Problem> problems) {
  final byKey = <String, List<Combo>>{};
  for (final p in problems) {
    byKey.putIfAbsent('${p.where}  ${p.summary}', () => []).add(p.combo);
  }
  final b = StringBuffer();
  for (final e in byKey.entries) {
    final sizes = e.value
        .map((c) => '${c.device.id}${c.landscape ? 'L' : ''}@${c.scale}'
            '${c.keyboard ? 'kb' : ''}')
        .toSet()
        .join(' ');
    b.writeln('• ${e.key}\n    ${e.value.length} cells: $sizes');
  }
  return b.toString();
}

/// Declares [c] as a test that fails on any layout problem.
void responsiveTest(ScreenCase c) {
  testWidgets(c.id, (tester) async {
    // The app's debug logging, silenced for the run (and restored: the
    // binding checks debugPrint is back after each test).
    final print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    final List<Problem> problems;
    try {
      problems = await runCase(tester, c);
    } finally {
      debugPrint = print;
    }
    expect(problems, isEmpty, reason: '\n${digest(problems)}');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// Taps the first widget matching [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder.first, warnIfMissed: false);
}

/// The router, for cases that push a second route.
GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(LahumaApp)))
    .read(routerProvider);

/// Context under the app's navigator, for calling a sheet's show function.
BuildContext pageContext(WidgetTester tester, Type screen) =>
    tester.element(find.byType(screen).last);
