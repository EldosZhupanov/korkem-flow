import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_price_table.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';

final facadePriceRepositoryProvider = Provider<FacadePriceRepository>((ref) {
  return FacadePriceRepository(ref.watch(frappeClientProvider));
});

/// Reads and edits the facade price matrix. Who may do either is the
/// server's decision; the shop floor is refused.
class FacadePriceRepository {
  const FacadePriceRepository(this._client);

  static const _base = 'korkem_manufacturing.api.facade_prices';
  static const readEndpoint = '$_base.read';
  static const saveEndpoint = '$_base.save';
  static const readRulesEndpoint = '$_base.read_settings';
  static const saveRulesEndpoint = '$_base.save_settings';
  static const quoteEndpoint = '$_base.quote';

  final FrappeClient _client;

  Future<FacadePriceTable> fetch() async =>
      _parsed(await _client.callMethod(readEndpoint));

  /// Saves one cell; the answer is the whole table as the server now has it.
  Future<FacadePriceTable> save({
    required String milling,
    required String finish,
    required double pricePerM2,
    bool enabled = true,
  }) async {
    final response = await _client.callMethod(
      saveEndpoint,
      post: true,
      params: {
        'milling': milling,
        'finish': finish,
        'price_per_m2': pricePerM2,
        'enabled': enabled ? 1 : 0,
      },
    );
    return _parsed(response);
  }

  Future<FacadeRules> fetchRules() async => FacadeRules.fromJson(
    _message(await _client.callMethod(readRulesEndpoint)),
  );

  /// Sends every rule; an empty value clears it (the server then refuses
  /// lines that need it).
  Future<FacadeRules> saveRules(FacadeRules rules) async {
    final response = await _client.callMethod(
      saveRulesEndpoint,
      post: true,
      params: {
        'double_sided_factor': rules.doubleSidedFactor ?? '',
        'customer_material_offered': rules.customerMaterialOffered ? 1 : 0,
        'customer_material_discount_percent':
            rules.customerMaterialDiscountPercent,
        'demolition_unit': rules.demolitionUnit ?? '',
        'demolition_rate': rules.demolitionRate ?? '',
        'prepayment_percent': rules.prepaymentPercent ?? '',
      },
    );
    return FacadeRules.fromJson(_message(response));
  }

  /// Prices an order on the server. Nothing is written.
  Future<FacadeQuote> quote(
    List<FacadeLineInput> lines, {
    bool demolition = false,
    double? prepaymentAmount,
  }) async {
    final response = await _client.callMethod(
      quoteEndpoint,
      post: true,
      params: {
        'lines': jsonEncode([for (final line in lines) line.toJson()]),
        'demolition': demolition ? 1 : 0,
        'prepayment_amount': ?prepaymentAmount,
      },
    );
    return FacadeQuote.fromJson(_message(response));
  }

  Map<String, dynamic> _message(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map || raw.isEmpty) {
      throw const ServerFailure('Сервер не ответил на расчёт.');
    }
    return Map<String, dynamic>.from(raw);
  }

  FacadePriceTable _parsed(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map || raw.isEmpty) {
      throw const ServerFailure('Сервер не вернул цены фасадов.');
    }
    return FacadePriceTable.fromJson(Map<String, dynamic>.from(raw));
  }
}
