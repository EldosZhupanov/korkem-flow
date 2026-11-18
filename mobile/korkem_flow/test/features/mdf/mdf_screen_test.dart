import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Every row of «МДФ» opens the screen that already lives at its route.
void main() {
  // In the order they stand on the screen, group by group (12.11.2026):
  // the test scrolls down to each in turn.
  const rows = {
    'orders': Routes.mdfOrders,
    'filmDept': Routes.filmDept,
    'quote': Routes.facadeQuote,
    'cash': Routes.mdfCash,
    'report': Routes.mdfReport,
    'volume': Routes.mdfVolume,
    'debts': Routes.mdfDebts,
    'jobs': Routes.facadeJobs,
    'press': Routes.pressSettings,
    'plan': Routes.mdfPlan,
    'tv': Routes.mdfTv,
    'batch': Routes.mdfBatch,
    'paint': Routes.mdfPaint,
    'stock': Routes.materialStock,
    'film': Routes.mdfFilm,
    'logistics': Routes.logistics,
    'dictionaries': Routes.mdfDictionaries,
    'glue': Routes.glue,
    'prices': Routes.facadePrices,
    'cncPatterns': Routes.cncPatterns,
  };

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: Routes.mdf,
      routes: [
        GoRoute(path: Routes.mdf, builder: (_, _) => const MdfScreen()),
        for (final path in rows.values)
          GoRoute(path: path, builder: (_, _) => Text('at $path')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the block is titled МДФ and lists its parts', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('МДФ'), findsOneWidget);
    for (final id in rows.keys) {
      // A ListView builds only what is near the screen; scroll to each.
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('mdf:$id')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ValueKey('mdf:$id')), findsOneWidget);
    }
  });

  for (final MapEntry(key: id, value: path) in rows.entries) {
    testWidgets('«$id» opens $path', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('mdf:$id')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(ValueKey('mdf:$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('mdf:$id')));
      await tester.pumpAndSettle();
      expect(find.text('at $path'), findsOneWidget);
    });
  }

  // Variant A (owner, 17.11.2026): the menu opens one part at a time, each
  // under its own name — and each holds its rows, no others.
  group('a section of the menu', () {
    Future<void> pumpSection(WidgetTester tester, MdfSection section) async {
      final router = GoRouter(
        initialLocation: '/section',
        routes: [
          GoRoute(
            path: '/section',
            builder: (_, _) => MdfScreen(section: section),
          ),
          for (final path in {...rows.values, Routes.mdfPlan})
            GoRoute(path: path, builder: (_, _) => Text('at $path')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            mdfPlanProvider.overrideWith(
              (ref) async => const MdfPlan(
                stages: [
                  PlanStage(stage: MdfStage.cut, orders: [], areaM2: 12.5),
                  PlanStage(stage: MdfStage.paint, orders: [], areaM2: 4),
                ],
                intake: [],
                inWorkM2: 16.5,
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final section in MdfSection.values) {
      testWidgets('«${section.name}» lists its rows and only them', (
        tester,
      ) async {
        await pumpSection(tester, section);
        for (final id in rows.keys) {
          expect(
            find.byKey(ValueKey('mdf:$id'), skipOffstage: false),
            section.rows.contains(id) ? findsOneWidget : findsNothing,
            reason: '$id in ${section.name}',
          );
        }
      });
    }

    testWidgets('«Фасады на заказ» shows the order path; a stage opens the '
        'plan', (tester) async {
      await pumpSection(tester, MdfSection.facades);
      expect(find.text('Фасады на заказ'), findsOneWidget);
      expect(find.byKey(const ValueKey('facades:path')), findsOneWidget);
      expect(find.text('Раскрой · 12.5 м²'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('facades:stage:paint')));
      await tester.pumpAndSettle();
      expect(find.text('at ${Routes.mdfPlan}'), findsOneWidget);
    });
  });
}
