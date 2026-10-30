import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/items/data/items_repository.dart';
import 'package:korkem_flow/features/items/domain/item.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final itemsUnitsProvider = FutureProvider.autoDispose<List<UnitOption>>((ref) {
  return ref.watch(itemsRepositoryProvider).fetchUnits();
});

/// Search query notifier for filtering items catalog.
class ItemsSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  String get query => state;
  set query(String val) => state = val;
  void clear() => state = '';
}

// AutoDisposeNotifierProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final itemsSearchQueryProvider =
    NotifierProvider.autoDispose<ItemsSearchQueryNotifier, String>(
      ItemsSearchQueryNotifier.new,
    );

/// Catalog items list, filtered by search query.
// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final itemsListProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final query = ref.watch(itemsSearchQueryProvider);
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.list(query: query.isEmpty ? null : query);
});
