import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';

import '../../support/widget_harness.dart';

/// The dashboard's tiles at every text scale the app claims to support.
///
/// §3 of the design system promises 1.0–1.6x "without clipping or overlap".
/// The grid used a fixed `childAspectRatio`, which ties a tile's height to its
/// *width* — so when the text grew the tile could not. At 1.6x the content
/// overflowed by 11 pixels, on the home screen, in the one setting visually
/// impaired users are most likely to have turned on.
///
/// The tile now declares the height it needs. These assertions compare that
/// declaration against what the tile *actually* takes when nothing constrains
/// it. The first version of this test compared the declaration against itself,
/// passed happily, and let through a version that was 4px short at normal
/// scale because it had forgotten the label row is as tall as its icon rather
/// than as tall as its text. A golden caught that; this now would.
void main() {
  const columnWidth = 187.0; // one column of the two-up phone grid

  /// What the tile takes when it is free to be its natural size.
  Future<double> naturalHeight(WidgetTester tester, double scale) async {
    await tester.pumpWidget(
      harness(
        // Aligned to the top and made intrinsic, so the tile reports the height
        // its content needs rather than filling the Scaffold it is dropped in.
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: columnWidth,
            child: IntrinsicHeight(
              // With its icon, as the dashboard always builds it: the label
              // row is the taller of icon and text, and a tile measured
              // without one is 4px shorter than any tile that ships.
              child: KpiTile(
                label: 'Открытые сделки',
                value: 266,
                icon: AppIcons.deal,
              ),
            ),
          ),
        ),
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(KpiTile)).height;
  }

  /// What the tile says it needs, which is what the grid allots it.
  Future<double> declaredHeight(WidgetTester tester, double scale) async {
    late double height;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) {
            height = KpiTile.heightFor(context);
            return const SizedBox.shrink();
          },
        ),
        textScale: scale,
      ),
    );
    return height;
  }

  for (final scale in const [1.0, 1.3, 1.6]) {
    testWidgets('the declared height covers the real one at ${scale}x', (
      tester,
    ) async {
      final natural = await naturalHeight(tester, scale);
      final declared = await declaredHeight(tester, scale);

      expect(
        declared,
        greaterThanOrEqualTo(natural),
        reason: 'the grid would clip the tile by ${natural - declared}px',
      );
    });

    testWidgets('and does not waste a row of space at ${scale}x', (
      tester,
    ) async {
      final natural = await naturalHeight(tester, scale);
      final declared = await declaredHeight(tester, scale);

      // Generous by no more than a hair. A declaration that simply added a
      // large margin would satisfy the test above while leaving a band of dead
      // space under every number on the home screen.
      expect(declared - natural, lessThan(2));
    });
  }

  testWidgets('the tile grows with the text, not with the column', (
    tester,
  ) async {
    final small = await declaredHeight(tester, 1);
    final large = await declaredHeight(tester, 1.6);

    // The assertion an aspect ratio could never satisfy: at a larger text scale
    // the tile asks for more room. A ratio returns the same number both times.
    expect(large, greaterThan(small));
  });
}
