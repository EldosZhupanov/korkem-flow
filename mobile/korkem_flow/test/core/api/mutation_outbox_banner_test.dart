import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/api/mutation_outbox_banner.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late MutationOutbox outbox;

  setUp(() {
    client = _MockClient();
    outbox = MutationOutbox(keyFactory: () => 'intent-1');
  });

  tearDown(() => outbox.dispose());

  Future<void> queueCommand() async {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenThrow(const NetworkFailure('offline'));
    await expectLater(
      outbox.execute(client, 'example.mutate', params: const {'id': 'DOC-1'}),
      throwsA(isA<MutationQueued>()),
    );
  }

  Future<void> pumpBanner(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        mutationOutboxProvider.overrideWithValue(outbox),
        frappeClientProvider.overrideWithValue(client),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MutationOutboxBanner()),
      ),
    ),
  );

  testWidgets('pending command count remains visible', (tester) async {
    await queueCommand();

    await pumpBanner(tester);
    await tester.pump();

    expect(find.text('1 command waiting to send'), findsOneWidget);
    expect(find.text('Send now'), findsOneWidget);
  });

  testWidgets('manual retry clears a delivered command', (tester) async {
    await queueCommand();
    reset(client);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenAnswer(
      (_) async => {
        'message': {'status': 'ok'},
      },
    );
    await pumpBanner(tester);
    await tester.pump();

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();

    expect(find.text('1 command waiting to send'), findsNothing);
    expect(outbox.snapshot.isEmpty, isTrue);
  });

  testWidgets('server refusal stays visible as an attention count', (
    tester,
  ) async {
    await queueCommand();
    reset(client);
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: true,
      ),
    ).thenAnswer(
      (_) async => {
        'message': {'status': 'blocked', 'message': 'No stock'},
      },
    );
    await pumpBanner(tester);
    await tester.pump();

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();

    expect(find.text('Commands needing attention: 1'), findsOneWidget);
    expect(find.textContaining('No stock'), findsNothing);
    expect(outbox.snapshot.pendingCount, 0);
    expect(outbox.snapshot.rejected.single.reason, 'No stock');
  });

  testWidgets('tapping banner navigates to /outbox', (tester) async {
    await queueCommand();

    var navigatedPath = '';
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: MutationOutboxBanner(),
          ),
        ),
        GoRoute(
          path: '/outbox',
          builder: (context, state) {
            navigatedPath = state.uri.path;
            return const Scaffold(body: Text('Outbox Screen'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mutationOutboxProvider.overrideWithValue(outbox),
          frappeClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the banner body (the pending count text)
    await tester.tap(find.text('1 command waiting to send'));
    await tester.pumpAndSettle();

    expect(navigatedPath, '/outbox');
    expect(find.text('Outbox Screen'), findsOneWidget);
  });
}
