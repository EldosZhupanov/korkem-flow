import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/memory/domain/memory_fact.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>(
  (ref) => MemoryRepository(ref.watch(frappeClientProvider)),
);

/// Repository for reading, updating, confirming, and deleting assistant memory
/// facts.
class MemoryRepository {
  const MemoryRepository(this._client);

  final FrappeClient _client;

  static const listEndpoint = 'korkem_ai.korkem_ai.memory_api.list';
  static const updateEndpoint = 'korkem_ai.korkem_ai.memory_api.update';
  static const confirmEndpoint = 'korkem_ai.korkem_ai.memory_api.confirm';
  static const deleteEndpoint = 'korkem_ai.korkem_ai.memory_api.delete';

  /// Fetches all memory facts for the company and current user.
  Future<List<MemoryFact>> fetchAll() async {
    final response = await _client.callMethod(listEndpoint);
    final data = response['message'];

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MemoryFact.fromJson)
          .toList(growable: false);
    }

    if (data is Map<String, dynamic>) {
      final list = <MemoryFact>[];

      if (data['company'] is List) {
        for (final item in data['company'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(
              MemoryFact.fromJson({
                ...item,
                if (!item.containsKey('scope')) 'scope': 'company',
              }),
            );
          }
        }
      }

      if (data['user'] is List) {
        for (final item in data['user'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(
              MemoryFact.fromJson({
                ...item,
                if (!item.containsKey('scope')) 'scope': 'user',
              }),
            );
          }
        }
      }

      if (data['items'] is List) {
        for (final item in data['items'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(MemoryFact.fromJson(item));
          }
        }
      }

      return List.unmodifiable(list);
    }

    return const [];
  }

  /// Updates the text of a memory fact.
  Future<MemoryFact> updateFact(String id, {required String text}) async {
    final response = await _client.callMethod(
      updateEndpoint,
      post: true,
      params: {
        'name': id,
        'value': text,
        'text': text,
      },
    );

    final data = response['message'];
    if (data is Map<String, dynamic>) {
      return MemoryFact.fromJson(data);
    }
    throw const ServerFailure('Invalid response from memory update.');
  }

  /// Marks a memory fact as confirmed by the user.
  Future<MemoryFact> confirmFact(String id) async {
    final response = await _client.callMethod(
      confirmEndpoint,
      post: true,
      params: {
        'name': id,
      },
    );

    final data = response['message'];
    if (data is Map<String, dynamic>) {
      return MemoryFact.fromJson(data);
    }
    throw const ServerFailure('Invalid response from memory confirm.');
  }

  /// Deletes a memory fact permanently.
  Future<void> deleteFact(String id) async {
    await _client.callMethod(
      deleteEndpoint,
      post: true,
      params: {
        'name': id,
      },
    );
  }
}
