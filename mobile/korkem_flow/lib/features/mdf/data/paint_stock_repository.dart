import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';

final paintStockRepositoryProvider = Provider<PaintStockRepository>(
  (ref) => PaintStockRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final paintStockProvider = FutureProvider.autoDispose<PaintStock>(
  (ref) => ref.watch(paintStockRepositoryProvider).stock(),
);

/// «Склад краски» — `korkem_manufacturing.api.paint_stock`.
class PaintStockRepository {
  const PaintStockRepository(this._client);

  static const _base = 'korkem_manufacturing.api.paint_stock';

  final FrappeClient _client;

  Future<PaintStock> stock() async =>
      _stock(await _client.callMethod('$_base.stock'));

  Future<List<PaintReceipt>> history(String item) async {
    final body = _map(
      await _client.callMethod('$_base.history', params: {'item': item}),
    );
    return [
      for (final r in body['receipts'] as List? ?? const [])
        if (r is Map) PaintReceipt.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// So many kilograms of a colour at so much a kilo — and how it came and
  /// was paid, as a film receipt says it.
  Future<PaintStock> receive({
    required String colour,
    required double kg,
    required double priceKg,
    required String supplier,
    String? base,
    Map<String, Object?>? delivery,
    String? receivedBy,
    FilmSupplierPay? supplierPay,
    String? note,
  }) async => _stock(
    await _client.callMethod(
      '$_base.receive',
      post: true,
      params: {
        'colour': colour,
        'kg': kg,
        'price_kg': priceKg,
        'supplier': supplier,
        'base': ?base,
        if (delivery != null) 'delivery': jsonEncode(delivery),
        'received_by': ?receivedBy,
        if (supplierPay != null)
          'supplier_pay': jsonEncode(supplierPay.toJson()),
        'note': ?note,
      },
    ),
  );

  Future<PaintStock> setKgPerM2(double value) async => _stock(
    await _client.callMethod(
      '$_base.set_kg_per_m2',
      post: true,
      params: {'value': value},
    ),
  );

  Future<PaintStock> paySupplier(String receipt, String method) async =>
      _stock(
        await _client.callMethod(
          '$_base.pay_supplier',
          post: true,
          params: {'receipt': receipt, 'method': method},
        ),
      );

  /// The painter weighed what is left of a paint.
  Future<PaintStock> count(String item, double kg) async => _stock(
    await _client.callMethod(
      '$_base.count',
      post: true,
      params: {'item': item, 'kg': kg},
    ),
  );

  Future<PaintStock> addSupplier(String name) async => _stock(
    await _client.callMethod(
      '$_base.add_supplier',
      post: true,
      params: {'name': name},
    ),
  );

  static PaintStock _stock(Map<String, dynamic> response) =>
      PaintStock.fromJson(_map(response));

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
