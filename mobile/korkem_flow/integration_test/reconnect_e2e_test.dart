import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/credential_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/data/assistant_channel.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Losing the socket, and coming back.
///
/// The disconnect is real and isolated to the socket: the harness drops
/// **port 9000 only**, with `iptables` on the device, so HTTP keeps working
/// throughout. Restarting the whole bench — which an earlier attempt did —
/// takes the gateway, the CRM and the session down together and proves
/// nothing about the transport.
///
/// The harness applies and removes that rule on a schedule; this test
/// cooperates by holding still through the window.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `debugPrint` throttles by default, and on a run this chatty it silently
  // drops lines — which made an earlier log look as though a socket had never
  // disconnected when the assertions said it had. The transport log *is* the
  // evidence here, so it must be complete.
  debugPrint = debugPrintSynchronously;

  const user = String.fromEnvironment('KORKEM_E2E_USER');
  const password = String.fromEnvironment('KORKEM_E2E_PASSWORD');

  /// How long the test holds still while the harness breaks the socket.
  ///
  /// The outage has to outlast socket.io's own liveness check or nothing
  /// happens at all: with the default `pingInterval` 25s and `pingTimeout` 20s,
  /// dropped packets are not noticed for up to ~45 seconds. A 30-second outage
  /// was measured as *undetected* — the connection was restored before the
  /// timeout fired, which is correct behaviour and proves nothing. So the
  /// harness blocks at +5s and restores at +70s, comfortably past it.
  const settleBy = Duration(seconds: 110);

  late ProviderContainer container;

  Future<void> signedIn() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        credentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(sessionProvider.notifier)
        .signIn(
          serverUrl: AppConfig.fromEnvironment().baseUrl,
          user: user,
          password: password,
        );
    await container.read(assistantInfoProvider.future);
  }

  Future<List<AssistantEvent>> ask(String prompt) => container
      .read(assistantRepositoryProvider)
      .send(prompt: prompt, history: const [])
      .toList();

  testWidgets(
    'the app survives losing the socket and works afterwards',
    (
      tester,
    ) async {
      await signedIn();

      // The channel's own view of the connection, recorded throughout.
      final seen = <ChannelStatus>[];
      final channel = container.read(assistantChannelProvider);
      expect(channel, isNotNull, reason: 'no channel was built');
      final watching = channel!.status.listen(seen.add);
      addTearDown(watching.cancel);

      // 1. A normal turn, before anything is broken.
      final before = await ask('Сколько сделок в статусе Negotiation? Кратко.');
      expect(
        before.whereType<AssistantFailed>(),
        isEmpty,
        reason: 'the baseline turn failed, so nothing after it means anything',
      );
      expect(before.whereType<AssistantDone>(), hasLength(1));

      // 2. The window. The harness drops port 9000 at +5s and restores it at
      //    +70s; the socket has to notice and come back on its own.
      //
      // Printed so the run log shows what the socket did, not merely whether
      // the test passed — that log is the evidence for the report.
      // ignore: avoid_print
      print('RECONNECT_PROBE window open');
      await Future<void>.delayed(settleBy);
      // The sequence is the evidence for the report; an assertion alone would
      // prove the outcome without showing the transition.
      // ignore: avoid_print
      print('RECONNECT_PROBE statuses=$seen');

      expect(
        seen,
        contains(ChannelStatus.disconnected),
        reason: 'the client never noticed the socket had gone',
      );
      expect(
        seen.last,
        ChannelStatus.connected,
        reason: 'the client did not come back: $seen',
      );

      // 3. The session must still be the same authenticated user.
      final who = await container
          .read(frappeClientProvider)
          .callMethod('frappe.auth.get_logged_user');
      expect(who['message'], user, reason: 'the session did not survive');

      // 4. A real turn after the outage — real Gemini, real CRM read tool.
      final after = await ask('Покажи мои открытые сделки. Кратко.');
      expect(
        after.whereType<AssistantFailed>(),
        isEmpty,
        reason: 'the turn after reconnect failed',
      );

      // 5. Exactly one answer. A duplicated listener would deliver two.
      expect(
        after.whereType<AssistantDone>(),
        hasLength(1),
        reason: 'duplicate `done` — the reconnect registered a second listener',
      );
      // A CRM read really ran after the outage.
      //
      // Deliberately *not* asserting that tool names are unique: a model
      // legitimately calls the same tool several times in one turn (four
      // `crm.search_deals` in a row is normal when it is paging statuses), so
      // name-uniqueness would fail on correct behaviour. The duplicate-listener
      // signal is the single `AssistantDone` above — a second subscription
      // would deliver every event twice, terminator included.
      final tools = after.whereType<AssistantToolActivity>().toList();
      expect(tools, isNotEmpty, reason: 'no CRM tool ran after reconnect');
      expect(
        tools.every((t) => t.tool.startsWith('crm.')),
        isTrue,
        reason: 'unexpected tool after reconnect: ${tools.map((t) => t.tool)}',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'a write after reconnect still creates exactly one record',
    (
      tester,
    ) async {
      // Phase 8 proved the write path through the user interface. The question
      // here is narrower: after the transport has dropped and come back, does
      // one request still produce one row? A duplicated subscription
      // would deliver the confirmation twice and write twice.
      await signedIn();

      final marker = 'Reconnect ${DateTime.now().millisecondsSinceEpoch}';
      final client = container.read(frappeClientProvider);

      Future<int> tasks() async => (await client.getList(
        'CRM Task',
        FrappeQuery(
          filters: [FrappeFilter.like('title', '%$marker%')],
        ),
      )).length;

      // Break and restore the socket first, so the write happens on a
      // *reconnected* channel rather than on the original one.
      // ignore: avoid_print
      print('RECONNECT_PROBE window open');
      await Future<void>.delayed(settleBy);

      final proposal = await container
          .read(assistantRepositoryProvider)
          .send(
            prompt: 'Создай задачу с названием "$marker". Просто создай.',
            history: const [],
          )
          .toList();

      final pause = proposal.whereType<AssistantNeedsConfirmation>().toList();
      expect(
        pause,
        hasLength(1),
        reason: 'expected one confirmation request, got ${pause.length}',
      );
      expect(await tasks(), 0, reason: 'a write ran before it was confirmed');

      final resumed = await container
          .read(assistantRepositoryProvider)
          .confirm(
            turnId: pause.single.turnId,
            callIds: [for (final call in pause.single.calls) call.id],
            prompt: 'yes',
            history: const [],
          )
          .toList();

      expect(resumed.whereType<AssistantFailed>(), isEmpty);
      expect(
        resumed.whereType<AssistantDone>(),
        hasLength(1),
        reason: 'duplicate terminator after reconnect',
      );
      expect(await tasks(), 1, reason: 'the write did not happen exactly once');

      final created = await client.getList(
        'CRM Task',
        FrappeQuery(
          filters: [FrappeFilter.like('title', '%$marker%')],
        ),
      );
      await client.callMethod(
        'frappe.client.delete',
        post: true,
        params: {'doctype': 'CRM Task', 'name': '${created.first['name']}'},
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
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
