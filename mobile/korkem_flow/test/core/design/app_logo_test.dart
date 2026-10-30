import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';

import '../../support/brand_assets.dart';
import '../../support/widget_harness.dart';

/// The brand artwork must actually reach the screen.
///
/// `Image.asset` decodes on a real event-loop turn, which a widget test never
/// gives it unless asked. Nothing fails when the decode has not landed — the
/// image simply is not there — so a committed `login_dark.png` sat with a blank
/// space where the logo goes while `login_light.png` looked perfect, because
/// `Brightness.dark` is the first enum value and ran first on a cold cache.
///
/// That reads exactly like a dark-mode bug in the app and is not one. This is
/// the assertion that would have caught it.
void main() {
  testBothThemes('the mark paints, in both themes', (tester, brightness) async {
    await tester.pumpWidget(
      harness(const AppLogo(), brightness: brightness),
    );
    await precacheBrandAssets(tester);

    expect(_painted(tester, AppLogo), isTrue);
  });

  testBothThemes('the lockup paints, in both themes', (
    tester,
    brightness,
  ) async {
    await tester.pumpWidget(
      harness(
        const AppLogo(layout: LogoLayout.lockup, size: 240),
        brightness: brightness,
      ),
    );
    await precacheBrandAssets(tester);

    expect(_painted(tester, AppLogo), isTrue);
  });

  testWidgets('the mark keeps the artwork proportions', (tester) async {
    await tester.pumpWidget(harness(const AppLogo(size: 120)));
    await precacheBrandAssets(tester);

    final size = tester.getSize(find.byType(Image));
    // The source is 452x591. Stretching a logo is the one thing a brand guide
    // always forbids, and it is invisible until someone who knows the mark
    // looks at it.
    expect(size.height, 120);
    expect(size.width, closeTo(120 * 452 / 591, 0.5));
  });
}

/// Whether anything was actually rasterised for [type].
///
/// `findsOneWidget` proves the widget is in the tree, which is exactly what was
/// true while the logo was missing. This checks the layer really has content.
bool _painted(WidgetTester tester, Type type) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byType(type), matching: find.byType(Image)),
  );
  final stream = image.image.resolve(ImageConfiguration.empty);
  var loaded = false;
  stream.addListener(
    ImageStreamListener((_, _) => loaded = true, onError: (_, _) {}),
  );
  return loaded;
}
