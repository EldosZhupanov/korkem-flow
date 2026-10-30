import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/memory/data/memory_repository.dart';
import 'package:korkem_flow/features/memory/domain/memory_fact.dart';

final memoryControllerProvider =
    AsyncNotifierProvider<MemoryController, List<MemoryFact>>(
      MemoryController.new,
    );

class MemoryController extends AsyncNotifier<List<MemoryFact>> {
  @override
  Future<List<MemoryFact>> build() {
    return ref.watch(memoryRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(memoryRepositoryProvider).fetchAll(),
    );
  }

  Future<void> updateFact(String id, {required String newText}) async {
    final updated = await ref
        .read(memoryRepositoryProvider)
        .updateFact(id, text: newText);

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.map((f) => f.id == id ? updated : f).toList(growable: false),
      );
    }
  }

  Future<void> confirmFact(String id) async {
    final confirmed = await ref.read(memoryRepositoryProvider).confirmFact(id);

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.map((f) => f.id == id ? confirmed : f).toList(growable: false),
      );
    }
  }

  Future<void> deleteFact(String id) async {
    await ref.read(memoryRepositoryProvider).deleteFact(id);

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.where((f) => f.id != id).toList(growable: false),
      );
    }
  }
}
