import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';

final costsRepositoryProvider = Provider<CostsRepository>(
  (ref) => CostsRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final costCatalogProvider = FutureProvider.autoDispose<CostCatalog>(
  (ref) => ref.watch(costsRepositoryProvider).items(archived: true),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final costBillsProvider = FutureProvider.autoDispose.family<CostBills, String>(
  (ref, month) => ref.watch(costsRepositoryProvider).bills(month),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final consumablesProvider = FutureProvider.autoDispose<Consumables>(
  (ref) => ref.watch(costsRepositoryProvider).consumables(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final moneyFlowProvider = FutureProvider.autoDispose.family<MoneyFlow, String>(
  (ref, month) => ref.watch(costsRepositoryProvider).money(month),
);

/// `korkem_manufacturing.api.costs` — the shop's costs (owner, 25.11.2026).
class CostsRepository {
  const CostsRepository(this._client);

  static const _base = 'korkem_manufacturing.api.costs';

  final FrappeClient _client;

  Future<CostCatalog> items({bool archived = false}) async =>
      CostCatalog.fromJson(
        _map(
          await _client.callMethod(
            '$_base.items',
            params: {'archived': archived ? 1 : 0},
          ),
        ),
      );

  /// A new cost item, or [name]'s changes.
  Future<CostItem> saveItem({
    required String title,
    required String group,
    required CostMode mode,
    required bool fixed,
    required String area,
    String? name,
    String unit = '',
    double monthlyLimit = 0,
  }) async => CostItem.fromJson(
    _map(
      await _client.callMethod(
        name == null ? '$_base.add_item' : '$_base.edit_item',
        post: true,
        params: {
          'name': ?name,
          'title': title,
          'group': group,
          'mode': mode.name,
          'behaviour': fixed ? 'fixed' : 'variable',
          'area': area,
          'unit': unit,
          'monthly_limit': monthlyLimit,
        },
      ),
    ),
  );

  Future<CostItem> archive(String name, {required bool archived}) async =>
      CostItem.fromJson(
        _map(
          await _client.callMethod(
            '$_base.archive_item',
            post: true,
            params: {'name': name, 'archived': archived ? 1 : 0},
          ),
        ),
      );

  /// [source] and [target] are one item: the source's history goes over.
  Future<CostItem> merge(String source, String target) async =>
      CostItem.fromJson(
        _map(
          await _client.callMethod(
            '$_base.merge_items',
            post: true,
            params: {'source': source, 'target': target},
          ),
        ),
      );

  /// A consumable not in the list, from the floor.
  Future<CostItem> quickAdd(String title, {String? unit}) async =>
      CostItem.fromJson(
        _map(
          await _client.callMethod(
            '$_base.quick_add',
            post: true,
            params: {'title': title, 'unit': ?unit},
          ),
        ),
      );

  Future<CostBills> bills(String month) async => CostBills.fromJson(
    _map(
      await _client.callMethod('$_base.bills', params: {'month': month}),
    ),
  );

  Future<CostBills> putBill(
    String item, {
    required String month,
    required double amount,
    double? meterFrom,
    double? meterTo,
    String? note,
  }) async => CostBills.fromJson(
    _map(
      await _client.callMethod(
        '$_base.put_bill',
        post: true,
        params: {
          'item': item,
          'month': month,
          'amount': amount,
          'meter_from': ?meterFrom,
          'meter_to': ?meterTo,
          'note': ?note,
        },
      ),
    ),
  );

  Future<Consumables> consumables() async => Consumables.fromJson(
    _map(await _client.callMethod('$_base.consumable_list')),
  );

  Future<Consumables> take(String item, double qty, {String? note}) async =>
      Consumables.fromJson(
        _map(
          await _client.callMethod(
            '$_base.take',
            post: true,
            params: {'item': item, 'qty': qty, 'note': ?note},
          ),
        ),
      );

  Future<Consumables> receive(
    String item, {
    required double qty,
    required double price,
    String? supplier,
  }) async => Consumables.fromJson(
    _map(
      await _client.callMethod(
        '$_base.receive',
        post: true,
        params: {
          'item': item,
          'qty': qty,
          'price': price,
          'supplier': ?supplier,
        },
      ),
    ),
  );

  Future<Consumables> setMinimum(String item, double minimum) async =>
      Consumables.fromJson(
        _map(
          await _client.callMethod(
            '$_base.set_minimum',
            post: true,
            params: {'item': item, 'minimum': minimum},
          ),
        ),
      );

  Future<MoneyFlow> money(String month) async => MoneyFlow.fromJson(
    _map(
      await _client.callMethod('$_base.money', params: {'month': month}),
    ),
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
