import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(Object? v) => v == null ? null : _d(v);
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in v is List ? v : const <Object>[])
    if (r is Map) Map<String, dynamic>.from(r),
];

/// «договорная»: priced for the job, no list price.
const cncByAgreement = 'договорная';

/// The units a service is sold in (`services/cnc_orders.UNITS`).
const List<String> cncUnits = [
  'шт',
  'лист',
  'пог.м',
  'м²',
  'мин',
  cncByAgreement,
];

/// Where a CNC order is (owner, 15.11.2026).
enum CncStatus {
  draft,
  queued,
  onMachine('on_machine'),
  ready,
  handedOver('handed_over'),
  cancelled;

  const CncStatus([this._wire]);

  final String? _wire;

  String get wire => _wire ?? name;

  static CncStatus parse(Object? value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => CncStatus.draft,
  );
}

/// One service of the price list.
@immutable
class CncService {
  const CncService({
    required this.id,
    required this.title,
    required this.unit,
    this.group,
    this.price = 0,
    this.priceTrade,
    this.minutes = 0,
    this.enabled = true,
  });

  factory CncService.fromJson(Map<String, dynamic> j) => CncService(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    unit: '${j['unit'] ?? 'шт'}',
    group: _s(j['group']),
    price: _d(j['price']),
    priceTrade: _dn(j['price_trade']),
    minutes: _d(j['minutes']),
    enabled: j['enabled'] != false,
  );

  final String id;
  final String title;
  final String unit;
  final String? group;
  final double price;
  final double? priceTrade;
  final double minutes;
  final bool enabled;

  bool get byAgreement => unit == cncByAgreement || price <= 0;
}

/// The shop's own sheet, to sell with the job.
typedef CncMaterial = ({
  String item,
  String title,
  String unit,
  double onHand,
  double cost,
});

/// What the customer brought: what, how many, its defects.
typedef CncIntake = ({String what, double qty, String unit, String? defects});

Map<String, Object?> cncIntakeJson(CncIntake i) => {
  'what': i.what,
  'qty': i.qty,
  'unit': i.unit,
  'defects': ?i.defects,
};

List<CncIntake> _intake(Object? v) => [
  for (final r in _rows(v))
    (
      what: '${r['what'] ?? ''}',
      qty: _d(r['qty']),
      unit: '${r['unit'] ?? 'шт'}',
      defects: _s(r['defects']),
    ),
];

/// A line as the manager types it: a service of the list, the shop's
/// material, or a job of its own.
@immutable
class CncLineInput {
  const CncLineInput({
    required this.qty,
    this.service,
    this.material,
    this.title,
    this.rate,
    this.note,
  });

  final String? service;
  final String? material;
  final String? title;
  final double qty;
  final double? rate;
  final String? note;

  Map<String, Object?> toJson() => {
    'service': ?service,
    'material': ?material,
    'title': ?title,
    'qty': qty,
    'rate': ?rate,
    'note': ?note,
  };
}

/// A line as the server priced it.
@immutable
class CncLine {
  const CncLine({
    required this.kind,
    required this.title,
    required this.qty,
    required this.rate,
    required this.amount,
    this.service,
    this.material,
    this.unit,
    this.minutes = 0,
    this.note,
    this.manualRate = false,
    this.noPrice = false,
  });

  factory CncLine.fromJson(Map<String, dynamic> j) => CncLine(
    kind: '${j['kind'] ?? 'service'}',
    title: '${j['title'] ?? ''}',
    qty: _d(j['qty']),
    rate: _d(j['rate']),
    amount: _d(j['amount']),
    service: _s(j['service']),
    material: _s(j['material']),
    unit: _s(j['unit']),
    minutes: _d(j['minutes']),
    note: _s(j['note']),
    manualRate: j['manual_rate'] == true,
    noPrice: j['no_price'] == true,
  );

  final String kind;
  final String title;
  final double qty;
  final double rate;
  final double amount;
  final String? service;
  final String? material;
  final String? unit;
  final double minutes;
  final String? note;
  final bool manualRate;
  final bool noPrice;
}

typedef CncExtra = ({String title, double amount});

List<CncExtra> _extras(Object? v) => [
  for (final r in _rows(v))
    (title: '${r['title'] ?? ''}', amount: _d(r['amount'])),
];

/// What `price` answers: the lines, urgency and the minimum, the total.
@immutable
class CncQuote {
  const CncQuote({
    this.lines = const [],
    this.extras = const [],
    this.total = 0,
    this.minutes = 0,
    this.makerPrices = false,
  });

  factory CncQuote.fromJson(Map<String, dynamic> j) => CncQuote(
    lines: [for (final r in _rows(j['lines'])) CncLine.fromJson(r)],
    extras: _extras(j['extras']),
    total: _d(j['total']),
    minutes: _d(j['minutes']),
    makerPrices: j['maker_prices'] == true,
  );

  final List<CncLine> lines;
  final List<CncExtra> extras;
  final double total;
  final double minutes;
  final bool makerPrices;
}

/// Its place in the machine's queue.
typedef CncPlace = ({double minutesAhead, String eta, bool onMachine});

typedef CncPayment = ({
  String entry,
  String date,
  double amount,
  String? method,
  bool cancelled,
});

/// Everything the order card shows.
@immutable
class CncCard {
  const CncCard({
    required this.name,
    required this.status,
    required this.customer,
    required this.customerName,
    required this.deliveryDate,
    this.phone,
    this.customerTags = const [],
    this.tags = const [],
    this.intake = const [],
    this.terms = false,
    this.lines = const [],
    this.extras = const [],
    this.minutes = 0,
    this.total = 0,
    this.paid = 0,
    this.debt = 0,
    this.payments = const [],
    this.notes,
    this.readyOn,
    this.handedOverOn,
    this.takenBy,
    this.holdReason,
    this.place,
    this.history = const [],
  });

  factory CncCard.fromJson(Map<String, dynamic> j) {
    final q = j['queue'];
    return CncCard(
      name: '${j['name']}',
      status: CncStatus.parse(j['status']),
      customer: '${j['customer'] ?? ''}',
      customerName: '${j['customer_name'] ?? ''}',
      deliveryDate: '${j['delivery_date'] ?? ''}',
      phone: _s(j['phone']),
      customerTags: [for (final t in j['customer_tags'] as List? ?? []) '$t'],
      tags: [for (final t in j['tags'] as List? ?? []) '$t'],
      intake: _intake(j['intake']),
      terms: j['terms'] == true,
      lines: [for (final r in _rows(j['lines'])) CncLine.fromJson(r)],
      extras: _extras(j['extras']),
      minutes: _d(j['minutes']),
      total: _d(j['total']),
      paid: _d(j['paid']),
      debt: _d(j['debt']),
      payments: [
        for (final p in _rows(j['payments']))
          (
            entry: '${p['entry'] ?? p['name'] ?? ''}',
            date: '${p['date'] ?? p['posting_date'] ?? ''}',
            amount: _d(p['amount']),
            method: _s(p['method']),
            cancelled: p['cancelled'] == true,
          ),
      ],
      notes: _s(j['notes']),
      readyOn: _s(j['ready_on']),
      handedOverOn: _s(j['handed_over_on']),
      takenBy: _s(j['taken_by']),
      holdReason: _s(j['hold_reason']),
      place: q is Map
          ? (
              minutesAhead: _d(q['minutes_ahead']),
              eta: '${q['eta'] ?? ''}',
              onMachine: q['on_machine'] == true,
            )
          : null,
      history: [
        for (final h in _rows(j['history']))
          (at: '${h['at'] ?? ''}', text: '${h['text'] ?? ''}'),
      ],
    );
  }

  final String name;
  final CncStatus status;
  final String customer;
  final String customerName;
  final String deliveryDate;
  final String? phone;
  final List<String> customerTags;
  final List<String> tags;
  final List<CncIntake> intake;
  final bool terms;
  final List<CncLine> lines;
  final List<CncExtra> extras;
  final double minutes;
  final double total;
  final double paid;
  final double debt;
  final List<CncPayment> payments;
  final String? notes;
  final String? readyOn;
  final String? handedOverOn;
  final String? takenBy;
  final String? holdReason;
  final CncPlace? place;
  final List<({String at, String text})> history;

  bool get urgent => tags.contains('urgent');
}

/// One order in the list.
typedef CncRow = ({
  String name,
  String customerName,
  CncStatus status,
  String due,
  double total,
  double debt,
  bool urgent,
  String? hold,
  String? eta,
  double minutes,
});

/// The list, with the machine's queue and what is owed above it.
@immutable
class CncListing {
  const CncListing({
    this.orders = const [],
    this.queueMinutes = 0,
    this.queueOrders = 0,
    this.ready = 0,
    this.debt = 0,
    this.settings,
  });

  factory CncListing.fromJson(Map<String, dynamic> j) => CncListing(
    orders: [
      for (final r in _rows(j['orders']))
        (
          name: '${r['name']}',
          customerName: '${r['customer_name'] ?? ''}',
          status: CncStatus.parse(r['status']),
          due: '${r['due'] ?? ''}',
          total: _d(r['total']),
          debt: _d(r['debt']),
          urgent: r['urgent'] == true,
          hold: _s(r['hold']),
          eta: _s(r['eta']),
          minutes: _d(r['minutes']),
        ),
    ],
    queueMinutes: _d(j['queue_minutes']),
    queueOrders: (j['queue_orders'] as num?)?.toInt() ?? 0,
    ready: (j['ready'] as num?)?.toInt() ?? 0,
    debt: _d(j['debt']),
    settings: j['settings'] is Map
        ? CncSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map))
        : null,
  );

  final List<CncRow> orders;
  final double queueMinutes;
  final int queueOrders;
  final int ready;
  final double debt;
  final CncSettings? settings;
}

/// Urgency's percentage, the minimum order, the machine's minutes a day.
@immutable
class CncSettings {
  const CncSettings({
    this.urgentPct = 20,
    this.minOrder = 0,
    this.dayMinutes = 480,
  });

  factory CncSettings.fromJson(Map<String, dynamic> j) => CncSettings(
    urgentPct: _d(j['urgent_pct']),
    minOrder: _d(j['min_order']),
    dayMinutes: _d(j['day_minutes']),
  );

  final double urgentPct;
  final double minOrder;
  final double dayMinutes;
}

/// «1 ч 40 мин» from minutes, the words given.
String cncDuration(double minutes, String h, String m) {
  final total = minutes.round();
  final hours = total ~/ 60;
  final rest = total % 60;
  if (hours == 0) return '$rest $m';
  return rest == 0 ? '$hours $h' : '$hours $h $rest $m';
}
