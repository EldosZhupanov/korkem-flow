import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/events/domain/proactive_event.dart';

/// Access to proactive events noticed by KORKEM and the dismissal endpoint.
class EventsRepository {
  const EventsRepository(this._client);

  static const pendingMethod = 'korkem_ai.korkem_ai.events_api.pending';
  static const dismissMethod = 'korkem_ai.korkem_ai.events_api.dismiss';

  final FrappeClient _client;

  Future<List<ProactiveEvent>> fetchPending() async {
    final response = await _client.callMethod(pendingMethod);
    final raw = response['message'] ?? response;
    if (raw is Map<String, dynamic>) {
      final eventsRaw = raw['events'];
      if (eventsRaw is List) {
        return eventsRaw
            .map(ProactiveEvent.fromJson)
            .whereType<ProactiveEvent>()
            .toList(growable: false);
      }
    }
    return const <ProactiveEvent>[];
  }

  Future<void> dismiss(String eventId) async {
    await _client.callMethod(
      dismissMethod,
      params: <String, dynamic>{'event_id': eventId},
      post: true,
    );
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(frappeClientProvider)),
);
