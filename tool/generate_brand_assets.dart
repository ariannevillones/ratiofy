// One-off utility (not a real test): renders the Ratiofy dot mark to PNG
// source images via Flutter's own renderer, for flutter_launcher_icons /
// flutter_native_splash to build every platform's app icon and splash
// screen from. Re-run `flutter test test/generate_brand_assets.dart` if the
// brand mark ever changes; the outputs in assets_generated/ are committed
// and referenced directly by pubspec.yaml, so don't delete that directory.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _seedColor = Color.fromARGB(255, 2, 174, 231);
const _outDir = 'assets_generated';

ThemeData _theme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    );

Future<void> _capture(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  required String fileName,
  Color? background,
}) async {
  // The default test surface is only 800x600 logical px, which silently
  // clamps larger captures (e.g. the 1024x1024 icon) down to that size.
  // Size the surface to fit this capture exactly, at 1:1 device pixels.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(),
      home: Material(
        color: background ?? Colors.transparent,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // toImage()/toByteData() do real (non-fake-clock) async work to encode the
  // PNG, which deadlocks under the test binding's fake-async zone unless
  // it's escaped via runAsync().
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    Directory(_outDir).createSync(recursive: true);
    final file = File('$_outDir/$fileName');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'Wrote ${file.path} (${size.width.toInt()}x${size.height.toInt()})',
    );
  });
}

/// Small dot over big dot — the same ratio-colon mark used inside
/// RatiofyWordmark, reused standalone as an icon-friendly symbol.
class _RatioDotsMark extends StatelessWidget {
  const _RatioDotsMark({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final smallDot = size * 0.34;
    final bigDot = size * 0.62;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: smallDot,
            height: smallDot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Container(
            width: bigDot,
            height: bigDot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('generate square app icon', (tester) async {
    const canvas = 1024.0;
    await _capture(
      tester,
      size: const Size(canvas, canvas),
      fileName: 'icon.png',
      child: Builder(
        builder: (context) {
          final primary = Theme.of(context).colorScheme.primary;
          return Container(
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(canvas * 0.22),
            ),
            alignment: Alignment.center,
            child: const _RatioDotsMark(color: Colors.white, size: canvas * 0.42),
          );
        },
      ),
    );
  });

  testWidgets('generate splash logo (dot mark on transparent)', (
    tester,
  ) async {
    // flutter_tester substitutes block glyphs for all text (deterministic
    // test font), so the splash image uses the dot mark rather than the
    // full text wordmark — the in-app loading screen (rendered by the real
    // engine at runtime) already shows the full RatiofyWordmark correctly.
    await _capture(
      tester,
      size: const Size(320, 320),
      fileName: 'splash_logo.png',
      background: Colors.transparent,
      child: Builder(
        builder: (context) {
          final primary = Theme.of(context).colorScheme.primary;
          return Center(child: _RatioDotsMark(color: primary, size: 220));
        },
      ),
    );
  });
}
