import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the brand artwork before a golden is captured.
///
/// `Image.asset` decodes asynchronously, and `pumpAndSettle` does not wait for
/// it — the decode happens on a real event-loop turn that a widget test never
/// gives it. A golden taken before the decode lands is simply missing the
/// image, silently, with no failure of any kind.
///
/// This is not hypothetical. `Brightness.dark` is the *first* value of the
/// enum, so every "for each brightness" loop runs dark first, on a cold image
/// cache — and the light pass then passes because the earlier test warmed it.
/// The result was a committed `login_dark.png` with a blank space where the
/// logo goes and a `login_light.png` showing it correctly, which reads exactly
/// like a dark-mode bug in the app and is not one.
///
/// `tester.runAsync` is what supplies the real turn the decoder needs.
Future<void> precacheBrandAssets(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp).first);

  for (final path in const [
    'assets/brand/korkem_mark.png',
    'assets/brand/korkem_lockup.png',
    'assets/brand/korkem_ring.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(path), context));
  }

  await tester.pumpAndSettle();
}
