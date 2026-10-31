import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Every row of «МДФ» opens the screen that already lives at its route.
void main() {
  const rows = {
    'orders': Routes.orders,
    'quote': Routes.facadeQuote,
    'jobs': Routes.facadeJobs,
    'press': Routes.pressSettings,
    'stock': Routes.materialStock,
    'logistics': Routes.logistics,
    'prices': Routes.facadePrices,
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

  testWidgets('the block is titled МДФ and lists the seven parts', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('МДФ'), findsOneWidget);
    for (final id in rows.keys) {
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
}
