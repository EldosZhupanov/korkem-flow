import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';

/// A period: the span and a day in it (`yyyy-MM-dd`).
typedef PeopleQuery = ({PeopleSpan span, String day});

/// One person's card: `employee` null — the one asking, his own.
typedef PersonQuery = ({String? employee, PeopleSpan span, String day});

final peopleReportRepositoryProvider = Provider<PeopleReportRepository>(
  (ref) => PeopleReportRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final peopleReportProvider = FutureProvider.autoDispose
    .family<PeopleReport, PeopleQuery>(
      (ref, q) => ref.watch(peopleReportRepositoryProvider).report(q),
    );

// The same: the family's type is not public.
// ignore: specify_nonobvious_property_types
final personCardProvider = FutureProvider.autoDispose
    .family<PersonCard, PersonQuery>(
      (ref, q) => ref.watch(peopleReportRepositoryProvider).card(q),
    );

/// «Сотрудники» (owner, 25.11.2026): who did what, earned what, was paid
/// what — read only; every figure is kept elsewhere.
class PeopleReportRepository {
  PeopleReportRepository(this._client);

  final FrappeClient _client;

  static const _base = 'korkem_manufacturing.api.team';

  Future<PeopleReport> report(PeopleQuery q) async => PeopleReport.fromJson(
    _map(
      await _client.callMethod(
        '$_base.report',
        params: {'period': q.span.name, 'day': q.day},
      ),
    ),
  );

  Future<PersonCard> card(PersonQuery q) async => PersonCard.fromJson(
    _map(
      await _client.callMethod(
        '$_base.person_card',
        params: {
          'employee': ?q.employee,
          'period': q.span.name,
          'day': q.day,
        },
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по команде.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
