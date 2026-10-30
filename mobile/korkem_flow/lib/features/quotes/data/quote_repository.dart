import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/quotes/domain/quote.dart';

/// Reads ERPNext `Quotation`.
class QuoteRepository {
  const QuoteRepository(this._client);

  static const doctype = 'Quotation';

  static const listFields = [
    'name',
    'status',
    'docstatus',
    'customer_name',
    'party_name',
    'transaction_date',
    'valid_till',
    'grand_total',
    'currency',
    'total_qty',
  ];

  final FrappeClient _client;

  Future<List<Quote>> fetchPage({
    required int pageSize,
    int offset = 0,
    QuoteStatus? status,
    String? search,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          if (status != null) FrappeFilter.equals('status', status.wireValue),
          if (search != null && search.trim().isNotEmpty)
            FrappeFilter.like('customer_name', '%${search.trim()}%'),
        ],
        orderBy: 'transaction_date desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  Future<Quote> fetchOne(String id) async =>
      fromJson(await _client.getDoc(doctype, id));

  static Quote fromJson(Map<String, dynamic> json) {
    return Quote(
      id: '${json['name']}',
      status: QuoteStatus.fromWire(json['status'] as String?),
      docStatus: switch (json['docstatus']) {
        final int value => value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      customerName: _text(json['customer_name']),
      partyName: _text(json['party_name']),
      transactionDate: DateTime.tryParse('${json['transaction_date']}'),
      validTill: DateTime.tryParse('${json['valid_till']}'),
      grandTotal: _number(json['grand_total']),
      currency: _text(json['currency']),
      totalQty: _number(json['total_qty']),
    );
  }

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
