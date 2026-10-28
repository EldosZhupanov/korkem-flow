import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/facade_jobs/domain/facade_job.dart';

final facadeJobRepositoryProvider = Provider<FacadeJobRepository>((ref) {
  return FacadeJobRepository(
    ref.watch(frappeClientProvider),
    ref.watch(mutationOutboxProvider),
  );
});

/// The facades the shop floor has to make, and their status.
class FacadeJobRepository {
  FacadeJobRepository(this._client, [MutationOutbox? outbox])
    : _outbox = outbox ?? MutationOutbox();

  static const _base = 'korkem_manufacturing.api.facade_jobs';
  static const jobsEndpoint = '$_base.jobs';
  static const setStatusEndpoint = '$_base.set_status';

  final FrappeClient _client;
  final MutationOutbox _outbox;

  Future<List<FacadeJob>> fetch({FacadeJobStatus? status}) async {
    final response = await _client.callMethod(
      jobsEndpoint,
      params: {'status': ?status?.wire},
    );
    final message = response['message'];
    final rows = message is Map ? message['jobs'] : null;
    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map) FacadeJob.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Through the outbox: a status set on the floor with no signal is sent
  /// when the connection is back, once.
  ///
  /// [crew], when a facade is finished by several people: who, and their
  /// shares in % (none — equal). The server splits the pay.
  Future<void> setStatus(
    String line,
    FacadeJobStatus status, {
    List<CrewShare>? crew,
  }) async {
    await _outbox.execute(
      _client,
      setStatusEndpoint,
      params: {
        'line': line,
        'status': status.wire,
        if (crew != null && crew.isNotEmpty)
          'crew': jsonEncode([
            for (final member in crew)
              {'user': member.user, 'share': ?member.share},
          ]),
      },
    );
  }
}
