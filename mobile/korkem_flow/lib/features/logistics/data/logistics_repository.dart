import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/logistics/domain/logistics.dart';

final logisticsRepositoryProvider = Provider<LogisticsRepository>(
  (ref) => LogisticsRepository(
    ref.watch(frappeClientProvider),
    ref.watch(mutationOutboxProvider),
  ),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final deliveriesProvider = FutureProvider.autoDispose
    .family<List<Delivery>, String>(
      (ref, month) => ref.watch(logisticsRepositoryProvider).deliveries(month),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final logisticsSummaryProvider = FutureProvider.autoDispose
    .family<LogisticsSummary, String>(
      (ref, month) => ref.watch(logisticsRepositoryProvider).summary(month),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final logisticsSuggestionsProvider =
    FutureProvider.autoDispose<LogisticsSuggestions>(
      (ref) => ref.watch(logisticsRepositoryProvider).suggestions(),
    );

/// «Логистика» (`korkem_manufacturing.api.logistics`): deliveries kept apart
/// from the material they brought.
class LogisticsRepository {
  LogisticsRepository(this._client, [MutationOutbox? outbox])
    : _outbox = outbox ?? MutationOutbox();

  static const _base = 'korkem_manufacturing.api.logistics';

  final FrappeClient _client;
  final MutationOutbox _outbox;

  Future<List<Delivery>> deliveries(String month) async {
    final data = _map(
      await _client.callMethod('$_base.listing', params: {'month': month}),
    );
    return [
      for (final r in data['deliveries'] as List? ?? const [])
        if (r is Map) Delivery.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  Future<LogisticsSummary> summary(String month) async =>
      LogisticsSummary.fromJson(
        _map(
          await _client.callMethod('$_base.summary', params: {'month': month}),
        ),
      );

  Future<LogisticsSuggestions> suggestions() async =>
      LogisticsSuggestions.fromJson(
        _map(await _client.callMethod('$_base.suggestions')),
      );

  /// Written once even if the network drops halfway (idempotency key).
  Future<void> record(NewDelivery delivery) async {
    await _outbox.execute(
      _client,
      '$_base.record',
      params: delivery.toParams(),
    );
  }

  Future<void> cancel(String delivery, String reason) async {
    await _client.callMethod(
      '$_base.cancel',
      post: true,
      params: {'delivery': delivery, 'reason': reason},
    );
  }

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по логистике.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
