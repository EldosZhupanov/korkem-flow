import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';

final glueStockRepositoryProvider = Provider<GlueStockRepository>(
  (ref) => GlueStockRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final glueStockProvider = FutureProvider.autoDispose<GlueStock>(
  (ref) => ref.watch(glueStockRepositoryProvider).stock(),
);

/// A month's glue reconciliation, by «2026-11».
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final glueMonthProvider = FutureProvider.autoDispose.family<GlueMonth, String>(
  (ref, month) => ref.watch(glueStockRepositoryProvider).reconcile(month),
);

/// «Клей для ПВХ» — `korkem_manufacturing.api.glue_stock`.
class GlueStockRepository {
  const GlueStockRepository(this._client);

  static const _base = 'korkem_manufacturing.api.glue_stock';

  final FrappeClient _client;

  Future<GlueStock> stock() async =>
      _stock(await _client.callMethod('$_base.stock'));

  Future<GlueMonth> reconcile(String month) async => GlueMonth.fromJson(
    _map(
      await _client.callMethod('$_base.reconcile', params: {'month': month}),
    ),
  );

  /// The norm put right to what a m² really took.
  Future<GlueStock> setNorm(String item, double gM2) async => _stock(
    await _client.callMethod(
      '$_base.set_glue',
      post: true,
      params: {'item': item, 'norm_g_m2': gM2},
    ),
  );

  /// A new glue with its card; the first one is the one in work.
  Future<GlueStock> addGlue(GlueCard card) async => _stock(
    await _client.callMethod(
      '$_base.add_glue',
      post: true,
      params: {'name': card.name, ..._glue(card)},
    ),
  );

  Future<GlueStock> setGlue(String item, GlueCard card) async => _stock(
    await _client.callMethod(
      '$_base.set_glue',
      post: true,
      params: {'item': item, ..._glue(card)},
    ),
  );

  /// A new barrel opened: this glue is taken from now on.
  Future<GlueStock> setInWork(String item) async => _stock(
    await _client.callMethod(
      '$_base.set_in_work',
      post: true,
      params: {'item': item},
    ),
  );

  /// The millings' factors — 1.0 is a smooth face.
  Future<GlueStock> setMilling(Map<String, double> factors) async => _stock(
    await _client.callMethod(
      '$_base.set_milling',
      post: true,
      params: {'factors': jsonEncode(factors)},
    ),
  );

  /// So many kilograms, litres or buckets at so much a kilo, a litre or a
  /// bucket — and how it came and was paid, as a film receipt says it.
  Future<GlueStock> receive({
    required String item,
    required double qty,
    required GlueUnit unit,
    required double price,
    required GlueUnit pricePer,
    required String supplier,
    Map<String, Object?>? delivery,
    String? receivedBy,
    FilmSupplierPay? supplierPay,
  }) async => _stock(
    await _client.callMethod(
      '$_base.receive',
      post: true,
      params: {
        'item': item,
        'qty': qty,
        'unit': unit.wire,
        'price': price,
        'price_per': pricePer.wire,
        'supplier': supplier,
        if (delivery != null) 'delivery': jsonEncode(delivery),
        'received_by': ?receivedBy,
        if (supplierPay != null)
          'supplier_pay': jsonEncode(supplierPay.toJson()),
      },
    ),
  );

  /// The storekeeper weighed what is left of a glue.
  Future<GlueStock> count(String item, double kg) async => _stock(
    await _client.callMethod(
      '$_base.count',
      post: true,
      params: {'item': item, 'kg': kg},
    ),
  );

  Future<GlueStock> paySupplier(
    String receipt,
    String method, {
    String? bank,
  }) async => _stock(
    await _client.callMethod(
      '$_base.pay_supplier',
      post: true,
      params: {'receipt': receipt, 'method': method, 'bank': ?bank},
    ),
  );

  /// A glue supplier. A company that sells film too is the same supplier.
  Future<GlueStock> addSupplier(PaintSupplierCard card) async => _stock(
    await _client.callMethod(
      '$_base.add_supplier',
      post: true,
      params: _card(card),
    ),
  );

  Future<GlueStock> setSupplier(String id, PaintSupplierCard card) async =>
      _stock(
        await _client.callMethod(
          '$_base.set_supplier',
          post: true,
          params: {'supplier': id, ..._card(card)},
        ),
      );

  static Map<String, Object?> _glue(GlueCard c) => {
    'origin': c.origin ?? '',
    'bucket_kg': c.bucketKg ?? '',
    'kg_per_litre': c.kgPerLitre,
    'norm_g_m2': c.normGM2,
    'reserve_kg': c.reserveKg,
    'markup_bucket': c.markupBucket,
    'markup_litre': c.markupLitre,
  };

  static Map<String, Object?> _card(PaintSupplierCard c) => {
    'name': c.name,
    'city': c.city ?? '',
    'contact': c.contact ?? '',
    'phone': c.phone ?? '',
    'whatsapp': c.whatsapp ?? '',
    'min_order': c.minOrder ?? '',
    'note': c.note ?? '',
  };

  static GlueStock _stock(Map<String, dynamic> response) =>
      GlueStock.fromJson(_map(response));

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
