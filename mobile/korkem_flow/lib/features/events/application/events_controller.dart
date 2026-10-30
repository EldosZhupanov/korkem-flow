import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/events/data/events_repository.dart';
import 'package:korkem_flow/features/events/domain/proactive_event.dart';

final eventsControllerProvider =
    AsyncNotifierProvider<EventsController, List<ProactiveEvent>>(
      EventsController.new,
    );

/// Manages the list of pending proactive events.
class EventsController extends AsyncNotifier<List<ProactiveEvent>> {
  @override
  Future<List<ProactiveEvent>> build() {
    return ref.watch(eventsRepositoryProvider).fetchPending();
  }

  /// Refetches pending events from the backend.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(eventsRepositoryProvider).fetchPending(),
    );
  }

  /// Dismisses a single event optimistically, removing it from this user's view
  /// and notifying the server endpoint.
  Future<void> dismiss(String eventId) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.where((e) => e.id != eventId).toList(growable: false),
      );
    }

    try {
      await ref.read(eventsRepositoryProvider).dismiss(eventId);
    } catch (_) {
      if (current != null) {
        state = AsyncData(current);
      }
      rethrow;
    }
  }
}
