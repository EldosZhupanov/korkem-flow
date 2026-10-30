import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/dashboard/data/dashboard_repository.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late DashboardRepository repository;

  setUp(() {
    client = _MockClient();
    repository = DashboardRepository(client);
  });

  void respond(Map<String, dynamic> message) {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer((_) async => {'message': message});
  }

  test('reads metrics and the attention list', () async {
    respond({
      'user': 'aidos@korkem.kz',
      'metrics': {'open_deals': 12, 'overdue_tasks': 3},
      'attention': [
        {
          'kind': 'pending_action',
          'name': 'PA-0001',
          'title': 'create_quote',
          'subtitle': 'CRM Deal CRM-DEAL-2026-00041',
          'due': '2026-07-29 12:00:00',
        },
      ],
    });

    final summary = await repository.fetch();

    expect(summary.user, 'aidos@korkem.kz');
    expect(summary[DashboardSummary.openDeals], 12);
    expect(summary.attention.single.kind, AttentionKind.pendingAction);
    expect(summary.attention.single.due, DateTime(2026, 7, 29, 12));
  });

  test('keeps null distinct from zero', () async {
    // The whole point of the endpoint's contract: a metric the caller may not
    // read comes back null, and a tile must show a dash rather than assert 0.
    respond({
      'user': 'rep@korkem.kz',
      'metrics': {'open_deals': 0, 'pending_actions': null},
    });

    final summary = await repository.fetch();

    expect(summary[DashboardSummary.openDeals], 0);
    expect(summary[DashboardSummary.pendingActions], isNull);
  });

  test('parses counts that arrive as strings', () async {
    respond({
      'user': 'a@b.kz',
      'metrics': {'open_deals': '7', 'open_leads': 'not a number'},
    });

    final summary = await repository.fetch();

    expect(summary[DashboardSummary.openDeals], 7);
    expect(summary[DashboardSummary.openLeads], isNull);
  });

  test('drops attention rows of an unknown kind', () async {
    // A newer backend may add kinds this build has no card for. Skipping one is
    // correct; rendering it as an arbitrary existing kind would be a lie.
    respond({
      'user': 'a@b.kz',
      'metrics': <String, dynamic>{},
      'attention': [
        {'kind': 'quality_hold', 'name': 'X', 'title': 'Unknown'},
        {'kind': 'overdue_task', 'name': '42', 'title': 'Real'},
      ],
    });

    final summary = await repository.fetch();

    expect(summary.attention, hasLength(1));
    expect(summary.attention.single.title, 'Real');
    // CRM Task names are integers on the wire but are carried as strings.
    expect(summary.attention.single.name, '42');
  });

  test('rejects a response that is not shaped like a summary', () {
    when(
      () => client.callMethod(
        any(),
        params: any(named: 'params'),
        post: any(named: 'post'),
      ),
    ).thenAnswer((_) async => {'message': 'pong'});

    expect(repository.fetch, throwsA(isA<ServerFailure>()));
  });
}
