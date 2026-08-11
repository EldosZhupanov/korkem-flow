import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 29 — the whole business loop, on a device, as three different people.
///
/// Customer orders → manager sees it and hands it to somebody → that somebody
/// accepts and starts production → customer asks what happened. One assistant
/// throughout: the same tool registry, the same `Pending Action` confirmation,
/// the same ERPNext underneath. What differs between the three is only who is
/// signed in, and that is the point being tested.
///
/// Each test signs in fresh, because the app holds one session and these are
/// three people. They run in order and the later ones depend on the earlier —
/// which is what "a loop" means; run the file, not a single case.
///
/// ```sh
/// flutter test integration_test/business_loop_e2e_test.dart \
///   -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=KORKEM_E2E_USER=korkem.client@example.com \
///   --dart-define=KORKEM_E2E_MANAGER=korkem.manager@example.com \
///   --dart-define=KORKEM_E2E_EMPLOYEE=korkem.ivan@example.com \
///   --dart-define=KORKEM_E2E_PASSWORD=...
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const customer = String.fromEnvironment('KORKEM_E2E_USER');
  const manager = String.fromEnvironment('KORKEM_E2E_MANAGER');
  const employee = String.fromEnvironment('KORKEM_E2E_EMPLOYEE');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');
  final baseUrl = AppConfig.fromEnvironment().baseUrl;

  late ProviderContainer container;

  /// Carried between tests: the order the customer places is the order the
  /// manager dispatches and the employee works on.
  String? placedOrder;

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(minutes: 3),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('timed out waiting for ${reason ?? 'condition'}');
  }

  Future<void> signIn(WidgetTester tester, String user) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KorkemFlowApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final fields = find.byType(TextFormField);
    await pumpUntil(
      tester,
      () => fields.evaluate().length >= 3,
      reason: 'the login form',
    );

    await tester.enterText(fields.at(0), baseUrl);
    await tester.enterText(fields.at(1), user);
    await tester.enterText(fields.at(2), password);
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(seconds: 1));

    await pumpUntil(
      tester,
      () => find.byType(TextFormField).evaluate().isEmpty,
      reason: 'sign-in to complete for $user',
    );
    await pumpUntil(
      tester,
      () => find.byType(TextField).evaluate().isNotEmpty,
      reason: 'the assistant composer',
    );
  }

  Future<void> ask(WidgetTester tester, String prompt) async {
    await pumpUntil(
      tester,
      () => !container.read(assistantBusyProvider),
      reason: 'the assistant to finish the previous turn',
      timeout: const Duration(minutes: 4),
    );

    final composer = find.byType(TextField).last;
    await tester.ensureVisible(composer);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(composer);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(composer, prompt);
    await tester.pump();

    final appears = DateTime.now().add(const Duration(minutes: 1));
    while (find.byKey(const ValueKey('send')).evaluate().isEmpty) {
      if (DateTime.now().isAfter(appears)) {
        fail('the send button never appeared for "$prompt"');
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump(const Duration(milliseconds: 500));
  }

  String transcript() => (container.read(activeThreadProvider)?.messages ?? [])
      .map((message) => '${message.role}: ${message.body}')
      .join('\n');

  String saidByAssistant() =>
      (container.read(activeThreadProvider)?.messages ?? [])
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.body)
          .join('\n');

  int repliesSoFar() => (container.read(activeThreadProvider)?.messages ?? [])
      .where((message) => message.role == ChatRole.assistant)
      .length;

  Future<void> replied(WidgetTester tester, int before) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(deadline)) {
      if (repliesSoFar() > before) {
        await tester.pump(const Duration(milliseconds: 500));
        return;
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('the assistant never answered. Said so far:\n${saidByAssistant()}');
  }

  /// Waits for the card, checks it names the tool, taps Confirm.
  Future<void> confirmCard(WidgetTester tester, String tool) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (find.byType(ConfirmationCard).evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('no ConfirmationCard for $tool. Transcript:\n${transcript()}');
      }
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -400));
      }
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(
      find.textContaining(tool),
      findsOneWidget,
      reason: 'the card must name the tool it would run',
    );

    final confirm = find.descendant(
      of: find.byType(ConfirmationCard),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(confirm);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 500));

    await pumpUntil(
      tester,
      () => container.read(pendingConfirmationProvider) == null,
      reason: 'the proposal to be resolved after confirming',
    );
  }

  FrappeClient client() => container.read(frappeClientProvider);

  const product = 'Шкаф Астана';
  const theirs = 'Караганда Мебель';

  testWidgets(
    '1. a customer places an order through the assistant',
    (tester) async {
      await signIn(tester, customer);

      // Deliberately incomplete: no date. The assistant must ask rather than
      // invent one, which is the difference between an order and a guess.
      var before = repliesSoFar();
      await ask(tester, 'Здравствуйте! Хочу заказать 5 шкафов Астана.');
      await replied(tester, before);

      before = repliesSoFar();
      await ask(tester, 'Нужно к 25 сентября 2026 года.');
      await replied(tester, before);

      await confirmCard(tester, 'sales.create_sales_order');
      await pumpUntil(
        tester,
        () => !container.read(assistantBusyProvider),
        reason: 'the order to be created',
        timeout: const Duration(minutes: 4),
      );

      // Read back from ERPNext as the customer — their own order, and only
      // theirs. The assistant's account of what it did is not evidence.
      final orders = await client().getList(
        'Sales Order',
        const FrappeQuery(
          fields: ['name', 'customer', 'status', 'grand_total'],
          orderBy: 'creation desc',
          limitPageLength: 5,
        ),
      );
      expect(orders, isNotEmpty, reason: 'no order reached ERPNext');
      final mine = orders.first;
      placedOrder = mine['name'] as String;

      expect(mine['customer'], isNot(theirs));
      expect(
        saidByAssistant(),
        isNot(contains(theirs)),
        reason: 'another customer was named to this one',
      );

      // Read through the *parent*. A child doctype cannot be listed whatever
      // the caller's rights on the document that owns it — the same constraint
      // Phase 22 hit on `Stock Entry Detail` and Phase 24 on
      // `Work Order Operation`. No permission was widened for a test.
      final order = await client().getDoc('Sales Order', placedOrder!);
      final items = (order['items'] as List).cast<Map<String, dynamic>>();

      expect(items, hasLength(1));
      expect(items.first['item_code'], product);
      expect((items.first['qty'] as num).toDouble(), 5.0);
      expect(
        (items.first['rate'] as num).toDouble(),
        greaterThan(0),
        reason: 'the price must come from the price list, not from nowhere',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets(
    '2. the manager sees it and hands it to somebody',
    (tester) async {
      await signIn(tester, manager);
      expect(placedOrder, isNotNull, reason: 'test 1 must run first');

      var before = repliesSoFar();
      await ask(tester, 'Покажи заказы, которые сейчас в работе.');
      await replied(tester, before);

      before = repliesSoFar();
      await ask(
        tester,
        'Передай Ивану задание по заказу $placedOrder: '
        'начать раскрой, срок 20 сентября 2026.',
      );
      await replied(tester, before);

      await confirmCard(tester, 'dispatch.assign_work');
      await pumpUntil(
        tester,
        () => !container.read(assistantBusyProvider),
        reason: 'the instruction to be recorded',
        timeout: const Duration(minutes: 4),
      );

      final instructions = await client().getList(
        'Work Instruction',
        FrappeQuery(
          fields: const [
            'name',
            'employee_user',
            'status',
            'sales_order',
            'company',
          ],
          filters: <FrappeFilter>[
            FrappeFilter.equals('sales_order', placedOrder),
          ],
        ),
      );
      expect(instructions, isNotEmpty, reason: 'nothing was dispatched');
      expect(instructions.first['employee_user'], employee);
      expect(instructions.first['company'], 'KORKEM');
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets(
    '3. the employee accepts it and starts the work',
    (tester) async {
      await signIn(tester, employee);

      var before = repliesSoFar();
      await ask(tester, 'Какие у меня задания?');
      await replied(tester, before);
      expect(
        saidByAssistant(),
        contains(placedOrder),
        reason: 'the employee was not shown the job they were given',
      );

      before = repliesSoFar();
      await ask(tester, 'Принял.');
      await replied(tester, before);
      await confirmCard(tester, 'dispatch.respond_to_instruction');
      await pumpUntil(
        tester,
        () => !container.read(assistantBusyProvider),
        reason: 'the acknowledgement to be recorded',
        timeout: const Duration(minutes: 4),
      );

      final instructions = await client().getList(
        'Work Instruction',
        FrappeQuery(
          fields: const ['name', 'status', 'acknowledged_at'],
          filters: <FrappeFilter>[
            FrappeFilter.equals('sales_order', placedOrder),
          ],
        ),
      );
      expect(instructions.first['status'], 'Acknowledged');
      expect(instructions.first['acknowledged_at'], isNotNull);

      // Phase 31: a delivery record is an administrator's audit surface, and
      // an employee is not one. That the acceptance produced exactly one
      // notification is checked in ERPNext afterwards, as an administrator —
      // a read performed by this employee could not prove it either way.
      await expectLater(
        () => client().getList(
          'Notification Delivery',
          const FrappeQuery(),
        ),
        throwsA(isA<PermissionFailure>()),
      );

      // And the work itself still reaches ERPNext through the tools that
      // already existed — the point of the phase is that nothing about
      // production moved into the messaging layer.
      before = repliesSoFar();
      await ask(tester, 'Запусти производство по заказу $placedOrder.');
      await replied(tester, before);
      await confirmCard(tester, 'manufacturing.start_production');
      await pumpUntil(
        tester,
        () => !container.read(assistantBusyProvider),
        reason: 'production to start',
        timeout: const Duration(minutes: 4),
      );

      final jobs = await client().getList(
        'Work Order',
        FrappeQuery(
          fields: const ['name', 'status', 'qty', 'produced_qty', 'company'],
          filters: <FrappeFilter>[
            FrappeFilter.equals('sales_order', placedOrder),
          ],
        ),
      );
      expect(jobs, isNotEmpty, reason: 'no work order was created');
      expect((jobs.first['qty'] as num).toDouble(), 5.0);
      expect(jobs.first['company'], 'KORKEM');

      // And the first stage of it — with one piece spoiled, because a shop
      // floor is not a happy path. The scrap goes through the mechanism Phase
      // 23 built; nothing about it moved into the messaging layer.
      before = repliesSoFar();
      await ask(tester, 'Раскрой закончен: 4 годные, 1 в брак.');
      await replied(tester, before);
      await confirmCard(tester, 'manufacturing.complete_operation');
      await pumpUntil(
        tester,
        () => !container.read(assistantBusyProvider),
        reason: 'the stage to be booked',
        timeout: const Duration(minutes: 4),
      );
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );

  testWidgets(
    '4. the customer asks what happened to their order',
    (tester) async {
      await signIn(tester, customer);

      final before = repliesSoFar();
      await ask(tester, 'Что с моим заказом и когда он будет готов?');
      await replied(tester, before);

      final said = saidByAssistant();
      expect(said, contains(placedOrder));
      expect(
        said,
        isNot(contains(theirs)),
        reason: 'another customer reached this one',
      );
      for (final leak in const ['MFG-WO', 'нет доступа', 'другому']) {
        expect(
          said,
          isNot(contains(leak)),
          reason: 'the customer was shown "$leak"',
        );
      }
      expect(
        find.byType(ConfirmationCard),
        findsNothing,
        reason: 'a customer was offered a write to confirm',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _MemoryStore implements CredentialStore {
  AuthCredentials? _credentials;
  String? _serverUrl;

  @override
  Future<AuthCredentials?> read() async => _credentials;

  @override
  Future<void> write(AuthCredentials credentials) async =>
      _credentials = credentials;

  @override
  Future<String?> readServerUrl() async => _serverUrl;

  @override
  Future<void> writeServerUrl(String url) async => _serverUrl = url;

  @override
  Future<void> clear() async {
    _credentials = null;
    _serverUrl = null;
  }
}
