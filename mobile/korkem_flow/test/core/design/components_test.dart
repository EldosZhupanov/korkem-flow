import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';
import 'package:korkem_flow/core/design/widgets/offline_banner.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';

import '../../support/widget_harness.dart';

void main() {
  group('StatusChip', () {
    testBothThemes('shows an icon and the label, never colour alone', (
      tester,
      brightness,
    ) async {
      await tester.pumpWidget(
        harness(
          const StatusChip(label: 'Won', intent: StatusIntent.success),
          brightness: brightness,
        ),
      );

      expect(find.text('Won'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('exposes a screen-reader status label', (tester) async {
      await tester.pumpWidget(
        harness(const StatusChip(label: 'Lost', intent: StatusIntent.danger)),
      );

      expect(find.bySemanticsLabel('Status: Lost'), findsOneWidget);
    });

    testWidgets('compact variant drops the icon but keeps the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const StatusChip(
            label: 'Won',
            intent: StatusIntent.success,
            compact: true,
          ),
        ),
      );

      expect(find.text('Won'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('ErrorView', () {
    testWidgets('shows the human message from _server_messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ErrorView(error: ValidationFailure('Quantity is required')),
        ),
      );

      // The business-rule text must reach the user, not raw JSON.
      expect(find.text('Quantity is required'), findsOneWidget);
    });

    testWidgets('offers retry only when a handler is given', (tester) async {
      await tester.pumpWidget(
        harness(const ErrorView(error: NetworkFailure('offline'))),
      );
      expect(find.byType(FilledButton), findsNothing);

      var retried = false;
      await tester.pumpWidget(
        harness(
          ErrorView(
            error: const NetworkFailure('offline'),
            onRetry: () => retried = true,
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('falls back to a friendly title for an unknown error', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const ErrorView(error: 'raw string')));

      expect(find.text('Something went wrong.'), findsOneWidget);
    });
  });

  group('EmptyView', () {
    testWidgets('never renders a bare "no data"', (tester) async {
      await tester.pumpWidget(harness(const EmptyView()));

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
        find.text('New items will appear here as they are created.'),
        findsOneWidget,
      );
    });
  });

  group('AppSearchField', () {
    testWidgets('debounces: one callback for a burst of keystrokes', (
      tester,
    ) async {
      final received = <String>[];
      await tester.pumpWidget(
        harness(AppSearchField(onChanged: received.add)),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.enterText(find.byType(TextField), 'ac');
      await tester.enterText(find.byType(TextField), 'acm');
      await tester.enterText(find.byType(TextField), 'acme');
      expect(received, isEmpty, reason: 'must not fire mid-typing');

      await tester.pump(const Duration(milliseconds: 350));
      expect(received, ['acme']);
    });

    testWidgets('clear button empties the field and reports it', (
      tester,
    ) async {
      final received = <String>[];
      await tester.pumpWidget(
        harness(AppSearchField(onChanged: received.add)),
      );

      await tester.enterText(find.byType(TextField), 'acme');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      await tester.tap(find.byIcon(AppIcons.close).first);
      await tester.pump();

      expect(received.last, '');
    });
  });

  group('filter sheet', () {
    testWidgets('"All" is distinguishable from dismissal', (tester) async {
      FilterChoice<String>? result;
      var opened = false;

      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                opened = true;
                result = await showFilterSheet<String>(
                  context: context,
                  title: 'Stage',
                  current: 'Won',
                  options: const [
                    FilterOption(value: 'Won', label: 'Won'),
                    FilterOption(value: 'Lost', label: 'Lost'),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Choosing "All" returns a choice holding null — not null itself, which
      // would be indistinguishable from swiping the sheet away.
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets('every option stays selectable, including the first', (
      tester,
    ) async {
      FilterChoice<String>? result;

      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showFilterSheet<String>(
                  context: context,
                  title: 'Stage',
                  options: const [
                    FilterOption(
                      value: 'Qualification',
                      label: 'Qualification',
                    ),
                    FilterOption(value: 'Won', label: 'Won'),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qualification'));
      await tester.pumpAndSettle();

      // Regression guard: an earlier version used the first status as a
      // "clear" sentinel, which made it impossible to select.
      expect(result!.value, 'Qualification');
    });
  });

  group('EntityCard', () {
    testBothThemes('renders title, subtitle, status and metadata', (
      tester,
      brightness,
    ) async {
      await tester.pumpWidget(
        harness(
          const EntityCard(
            title: 'Acme LLC',
            subtitle: 'kitchen facades',
            statusLabel: 'Won',
            statusIntent: StatusIntent.success,
            metadata: [
              EntityMeta(icon: AppIcons.call, label: '77010001122'),
            ],
          ),
          brightness: brightness,
        ),
      );

      expect(find.text('Acme LLC'), findsOneWidget);
      expect(find.text('kitchen facades'), findsOneWidget);
      expect(find.text('Won'), findsOneWidget);
      expect(find.text('77010001122'), findsOneWidget);
    });

    testWidgets('is tappable as a whole', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        harness(EntityCard(title: 'Acme', onTap: () => tapped = true)),
      );

      await tester.tap(find.text('Acme'));
      expect(tapped, isTrue);
    });
  });

  group('KpiTile', () {
    testWidgets('loading placeholder keeps the tile the same height', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 200,
            child: KpiTile(label: 'Open orders', value: '12', isLoading: true),
          ),
        ),
      );
      final loadingHeight = tester.getSize(find.byType(KpiTile)).height;

      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 200,
            child: KpiTile(label: 'Open orders', value: '12'),
          ),
        ),
      );
      final loadedHeight = tester.getSize(find.byType(KpiTile)).height;

      // No layout shift between skeleton and value.
      expect(loadedHeight, loadingHeight);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('OfflineBanner', () {
    testWidgets('occupies no space when online', (tester) async {
      await tester.pumpWidget(harness(const OfflineBanner(visible: false)));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });

    testWidgets('explains why data may be stale when offline', (tester) async {
      await tester.pumpWidget(harness(const OfflineBanner(visible: true)));
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Showing saved data."),
        findsOneWidget,
      );
    });
  });

  group('accessibility', () {
    testWidgets('interactive targets meet the 48dp floor', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Save')),
              OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
            ],
          ),
        ),
      );

      for (final finder in [
        find.byType(FilledButton),
        find.byType(OutlinedButton),
      ]) {
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(AppTouchTarget.min),
        );
      }
    });

    testWidgets('layout survives 1.6x text scaling without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const EntityCard(
            title: 'Очень длинное название организации',
            subtitle: 'кухонные фасады МДФ с покрытием',
            statusLabel: 'Proposal/Quotation',
            statusIntent: StatusIntent.info,
          ),
          textScale: 1.6,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Kazakh text without exception', (tester) async {
      await tester.pumpWidget(
        harness(
          const EntityCard(
            title: 'Өндіріс тапсырмасы',
            subtitle: 'Қосымша тапсырыс — ұзындығы 2400 мм',
          ),
          locale: const Locale('kk'),
        ),
      );

      expect(find.text('Өндіріс тапсырмасы'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
