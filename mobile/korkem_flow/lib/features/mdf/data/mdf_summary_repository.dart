import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_summary.dart';

final mdfSummaryRepositoryProvider = Provider<MdfSummaryRepository>(
  (ref) => MdfSummaryRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfSummaryProvider = FutureProvider.autoDispose
    .family<MdfSummary, MdfPeriod>(
      (ref, p) => ref
          .watch(mdfSummaryRepositoryProvider)
          .summary(since: p.since, until: p.until),
    );

/// «Итоги МДФ» — `korkem_manufacturing.api.mdf_orders.summary`.
class MdfSummaryRepository {
  const MdfSummaryRepository(this._client);

  static const _base = 'korkem_manufacturing.api.mdf_orders';

  final FrappeClient _client;

  Future<MdfSummary> summary({
    required String since,
    required String until,
  }) async {
    final response = await _client.callMethod(
      '$_base.summary',
      params: {'since': since, 'until': until},
    );
    final raw = response['message'] ?? response;
    return MdfSummary.fromJson(
      raw is Map<String, dynamic> ? raw : const <String, dynamic>{},
    );
  }

  /// The month's goal in m²; null — none.
  Future<void> setTarget(double? m2) => _client.callMethod(
    '$_base.set_target',
    post: true,
    params: {'m2': m2 ?? ''},
  );
}
