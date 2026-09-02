import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/workstations/domain/station_operation.dart';
import 'package:korkem_flow/features/workstations/domain/workstation_item.dart';

final workstationRepositoryProvider = Provider<WorkstationRepository>(
  (ref) => WorkstationRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final workstationsProvider = FutureProvider.autoDispose<List<WorkstationItem>>(
  (ref) => ref.watch(workstationRepositoryProvider).fetchWorkstations(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final stationQueueProvider = FutureProvider.autoDispose
    .family<List<StationOperation>, String>(
      (ref, workstation) => ref
          .watch(workstationRepositoryProvider)
          .fetchStationQueue(workstation),
    );

/// Reading workstations and their operations queue directly from the server.
class WorkstationRepository {
  const WorkstationRepository(this._client);

  static const workstationsPath =
      'korkem_manufacturing.api.queries.workstations';
  static const queuePath = 'korkem_manufacturing.api.queries.station_queue';

  final FrappeClient _client;

  /// Fetches workstations that currently have unfinished work waiting.
  Future<List<WorkstationItem>> fetchWorkstations({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.callMethod(
      workstationsPath,
      params: {'limit': limit, 'offset': offset},
    );
    final raw = response['message'] ?? response;
    final list = raw is Map<String, dynamic> ? raw['workstations'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(WorkstationItem.fromJson)
        .toList(growable: false);
  }

  /// Fetches unfinished operations waiting at [workstation], soonest first.
  Future<List<StationOperation>> fetchStationQueue(
    String workstation, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.callMethod(
      queuePath,
      params: {
        'workstation': workstation,
        'limit': limit,
        'offset': offset,
      },
    );
    final raw = response['message'] ?? response;
    final list = raw is Map<String, dynamic> ? raw['operations'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(StationOperation.fromJson)
        .toList(growable: false);
  }
}
