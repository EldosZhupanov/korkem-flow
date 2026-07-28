import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';
import 'package:korkem_flow/features/warehouse/domain/stock_item.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(frappeClientProvider)),
);

final itemSearchProvider = NotifierProvider<ItemSearchNotifier, String?>(
  ItemSearchNotifier.new,
);

class ItemSearchNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) =>
      state = (value == null || value.isEmpty) ? null : value;
}

final warehouseControllerProvider =
    AsyncNotifierProvider<WarehouseController, PagedList<StockItem>>(
      WarehouseController.new,
    );

class WarehouseController extends PagedListController<StockItem> {
  @override
  Future<List<StockItem>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    final search = ref.watch(itemSearchProvider);

    return ref
        .read(stockRepositoryProvider)
        .fetchItems(pageSize: pageSize, offset: offset, search: search);
  }
}

/// Per-warehouse balances for one item, loaded when its row is expanded.
// ignore: specify_nonobvious_property_types — the generics are right there.
final stockBalancesProvider = FutureProvider.family<List<StockBalance>, String>(
  (ref, itemCode) => ref.watch(stockRepositoryProvider).fetchBalances(itemCode),
);
