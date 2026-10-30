import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/gallery/design_gallery.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

import '../support/brand_assets.dart';

/// One golden per tab per theme, over the whole component catalogue.
///
/// This is the cheapest coverage in the suite. A change to a shared token —
/// a tint, a radius, a type step — shows up here with every affected component
/// visible in the same diff, instead of surfacing in whichever feature screen
/// happened to be goldened and looking like a bug in that feature.
void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    group('golden: gallery $suffix', () {
      for (final (index, tab) in const [
        'foundations',
        'components',
        'states',
      ].indexed) {
        testWidgets(tab, (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.dark()
                    : AppTheme.light(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                // Reduced motion, for two reasons. The skeleton shimmer repeats
                // forever, so `pumpAndSettle` never returns against it — and
                // the design system already honours this flag, so asking for it
                // here also exercises the path where every duration collapses
                // to zero. A golden of an animation mid-flight would be a
                // golden of a race.
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: const DesignGallery(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          if (index > 0) {
            await tester.tap(find.byType(Tab).at(index));
            await tester.pumpAndSettle();
          }

          await precacheBrandAssets(tester);
          await expectLater(
            find.byType(DesignGallery),
            matchesGoldenFile('gallery_${tab}_$suffix.png'),
          );
        });
      }
    });
  }
}
