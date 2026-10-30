import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The filter sheet, and the difference between "dismissed" and "chose All".
void main() {
  late List<FilterChoice<String>?> results;

  Future<void> open(WidgetTester tester) async {
    results = [];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => results.add(
                  await showFilterSheet<String>(
                    context: context,
                    title: 'Filter',
                    current: 'Won',
                    options: const [
                      FilterOption(value: 'Won', label: 'Won'),
                      FilterOption(value: 'Lost', label: 'Lost'),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers a visible way out, not only a drag', (tester) async {
    await open(tester);

    // `docs/design_system.md` §8 has required this of every sheet from the
    // start, and this sheet shipped without it. A drag handle is an affordance
    // only for someone who already knows sheets drag; someone who opened this
    // by accident had nothing to aim at.
    final close = find.widgetWithIcon(IconButton, AppIcons.close);
    expect(close, findsOneWidget);

    await tester.tap(close);
    await tester.pumpAndSettle();

    // Closed *without* choosing: null, not a FilterChoice holding null.
    expect(results, [null]);
  });

  testWidgets('choosing All is a choice, not a dismissal', (tester) async {
    await open(tester);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // The distinction the FilterChoice wrapper exists for. Collapsing these
    // two into one nullable would make "show everything" unselectable, because
    // it is indistinguishable from backing out.
    expect(results.single, isA<FilterChoice<String>>());
    expect(results.single!.value, isNull);
  });

  testWidgets('the current value is the one marked selected', (tester) async {
    await open(tester);

    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Won'), matching: find.byType(ListTile)),
    );

    expect(tile.selected, isTrue);
  });
}
