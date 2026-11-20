import 'package:flutter/foundation.dart';

/// VAT in Kazakhstan from 2026 (the new Tax Code), % — the server's
/// `mdf_invoices.VAT_RATE`.
const int mdfVatRate = 16;

/// Where an invoice stands: waited for, paid in part, paid, struck out.
enum MdfInvoiceState {
  open,
  part,
  paid,
  cancelled;

  static MdfInvoiceState parse(Object? v) => switch ('$v') {
    'part' => part,
    'paid' => paid,
    'cancelled' => cancelled,
    _ => open,
  };
}

/// One line of an invoice, as it was printed.
typedef MdfInvoiceLine = ({
  String name,
  double qty,
  String unit,
  double price,
  double amount,
});

/// «Счёт на оплату» of an MDF order (owner, 20.11.2026): its number in the
/// company's one series, the day it was made and the day to pay by, whom
/// to, what for, and what has come by it.
@immutable
class MdfInvoice {
  const MdfInvoice({
    required this.no,
    required this.on,
    required this.dueOn,
    required this.amount,
    required this.payer,
    this.bin = '',
    this.vat = 0,
    this.lines = const [],
    this.paid = 0,
    this.state = MdfInvoiceState.open,
  });

  factory MdfInvoice.fromJson(Map<String, dynamic> j) => MdfInvoice(
    no: '${j['no'] ?? ''}',
    on: '${j['on'] ?? ''}',
    dueOn: '${j['due_on'] ?? ''}',
    amount: _d(j['amount']),
    payer: '${j['payer'] ?? ''}',
    bin: '${j['bin'] ?? ''}',
    vat: _d(j['vat']).round(),
    lines: [
      for (final l in j['lines'] is List ? j['lines'] as List : const [])
        if (l is Map)
          (
            name: '${l['name'] ?? ''}',
            qty: _d(l['qty']),
            unit: '${l['unit'] ?? ''}',
            price: _d(l['price']),
            amount: _d(l['amount']),
          ),
    ],
    paid: _d(j['paid']),
    state: MdfInvoiceState.parse(j['state']),
  );

  final String no;
  final String on;
  final String dueOn;
  final double amount;

  /// Who pays — a ТОО, an ИП, the customer himself — and his БИН/ИИН.
  final String payer;
  final String bin;

  /// VAT in the sum, %; 0 — without VAT.
  final int vat;
  final List<MdfInvoiceLine> lines;
  final double paid;
  final MdfInvoiceState state;

  /// Still to come by it.
  double get left => amount - paid > 0 ? amount - paid : 0;

  /// Waited for: open or paid in part.
  bool get waited =>
      state == MdfInvoiceState.open || state == MdfInvoiceState.part;
}

/// An invoice to print: as it was issued, with the factory's requisites.
typedef MdfInvoicePrint = ({MdfInvoice invoice, Map<String, String> requisites});

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
