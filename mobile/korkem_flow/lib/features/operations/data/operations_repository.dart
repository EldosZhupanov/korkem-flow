import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/operations/domain/delivery.dart';

/// The client half of the channel operations API.
///
/// Every method here is an administrator's action on the *server's* record of
/// what it tried to send. Nothing in this file can address a chat directly:
/// retry takes a delivery's name, and who that delivery is for was decided when
/// the business event happened.
/// The board and its per-state totals, together — the totals are what the
/// filter chips count, and fetching them separately would let the two disagree.
class DeliveryBoard {
  const DeliveryBoard({required this.deliveries, required this.summary});

  final List<NotificationDelivery> deliveries;
  final Map<String, int> summary;
}

class OperationsRepository {
  const OperationsRepository(this._client);

  static const _base = 'korkem_ai.korkem_ai.channels_api';

  final FrappeClient _client;

  Future<DeliveryBoard> deliveries({String? status, String? channel}) async {
    final response = await _client.callMethod(
      '$_base.list_deliveries',
      params: {'status': ?status, 'channel': ?channel},
    );
    final message = response['message'] as Map? ?? const {};
    return DeliveryBoard(
      deliveries: [
        for (final raw in (message['deliveries'] as List? ?? const []))
          NotificationDelivery.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      summary: {
        for (final entry in (message['summary'] as Map? ?? const {}).entries)
          entry.key as String: (entry.value as num).toInt(),
      },
    );
  }

  Future<bool> retry(String name) async {
    final response = await _client.callMethod(
      '$_base.retry_delivery',
      post: true,
      params: {'name': name},
    );
    return (response['message'] as Map? ?? const {})['ok'] == true;
  }

  Future<bool> cancel(String name) async {
    final response = await _client.callMethod(
      '$_base.cancel_delivery',
      post: true,
      params: {'name': name},
    );
    return (response['message'] as Map? ?? const {})['ok'] == true;
  }

  Future<int> retryAll() async {
    final response = await _client.callMethod(
      '$_base.retry_all_deliveries',
      post: true,
    );
    final message = response['message'] as Map? ?? const {};
    return (message['sent'] as num? ?? 0).toInt();
  }

  Future<List<WorkInstructionRow>> instructions({String? status}) async {
    final response = await _client.callMethod(
      '$_base.list_work_instructions',
      params: {'status': ?status},
    );
    final message = response['message'] as Map? ?? const {};
    return [
      for (final raw in (message['instructions'] as List? ?? const []))
        WorkInstructionRow.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  Future<({bool ok, String? code})> sendTestMessage(String channel) async {
    final response = await _client.callMethod(
      '$_base.send_test_message',
      post: true,
      params: {'channel': channel},
    );
    final message = response['message'] as Map? ?? const {};
    return (ok: message['ok'] == true, code: message['code'] as String?);
  }

  Future<void> disconnect(String channel) => _client.callMethod(
    '$_base.disconnect_channel',
    post: true,
    params: {'channel': channel},
  );
}

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => OperationsRepository(ref.watch(frappeClientProvider)),
);

/// The board, narrowed to one state or to everything.
///
/// A family rather than a filter held in a provider: which chip is selected is
/// view state — it belongs to the screen that shows the chips, and making it
/// app state would mean two widgets could disagree about it.
/// `allStates` means "do not narrow" — a plain string rather than a null,
/// because a nullable family argument buys nothing here and reads worse at
/// every call site.
const String allStates = 'All';

// ignore: specify_nonobvious_property_types — the generics are right there.
final deliveriesProvider = FutureProvider.family<DeliveryBoard, String>(
  (ref, status) => ref
      .watch(operationsRepositoryProvider)
      .deliveries(status: status == allStates ? null : status),
);

final workInstructionsProvider = FutureProvider<List<WorkInstructionRow>>(
  (ref) => ref.watch(operationsRepositoryProvider).instructions(),
);
