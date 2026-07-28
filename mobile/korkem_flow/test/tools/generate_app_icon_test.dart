@Tags(['tools'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';

/// Renders the launcher icon source images.
///
/// Not a test of behaviour — a build tool that borrows the golden mechanism,
/// which is the one thing in this toolchain that can rasterise a widget to a
/// PNG. Regenerate with:
///
/// ```sh
/// flutter test test/tools/generate_app_icon_test.dart --update-goldens --tags tools
/// ```
///
/// Doing it this way rather than hand-drawing an icon in an image editor means
/// the icon is built from the same `AppColors` tokens and the same bundled
/// Inter as the app: change the brand green in one place and the launcher icon
/// follows. It is tagged `tools` so a normal `flutter test` run skips it.
void main() {
  testWidgets('app icon', (tester) async {
    await _pump(tester, const AppLogo(size: _size, fullBleed: true));

    await expectLater(
      find.byType(AppLogo),
      matchesGoldenFile('../../assets/icon/app_icon.png'),
    );
  });

  testWidgets('adaptive foreground', (tester) async {
    // Android masks an adaptive icon to an arbitrary shape and only the middle
    // ~66% is guaranteed visible, so the glyph is drawn small on a transparent
    // field rather than filling the canvas.
    await _pump(
      tester,
      const AppLogo(size: _size, transparent: true, glyphScale: 0.42),
    );

    await expectLater(
      find.byType(AppLogo),
      matchesGoldenFile('../../assets/icon/app_icon_foreground.png'),
    );
  });
}

/// Play wants 512×512; 1024 gives every launcher density a clean downscale.
const _size = 1024.0;

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(_size, _size)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Material, not a bare ColoredBox: text outside a Material ancestor
      // picks up Flutter's yellow debug underline and it lands in the PNG.
      home: Material(
        color: AppColors.surfaceDark,
        child: Center(child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
