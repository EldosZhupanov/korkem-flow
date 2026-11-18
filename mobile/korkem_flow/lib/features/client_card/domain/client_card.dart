import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:meta/meta.dart';

/// One order on a customer's card — a facade or a CNC one.
@immutable
class ClientOrder {
  const ClientOrder({
    required this.name,
    required this.status,
    this.number,
    this.cnc = false,
    this.createdOn,
    this.due,
    this.decor,
    this.total = 0,
    this.paid = 0,
    this.debt = 0,
    this.toldOn,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> j) => ClientOrder(
    name: '${j['name']}',
    status: '${j['status'] ?? ''}',
    number: _i(j['number']),
    cnc: j['cnc'] == true,
    createdOn: _s(j['created_on']),
    due: _s(j['due']),
    decor: _s(j['decor']),
    total: _d(j['total']),
    paid: _d(j['paid']),
    debt: _d(j['debt']),
    toldOn: _s(j['told_on']),
  );

  final String name;

  /// The wire status: `MdfStatus` or `CncStatus` by [cnc].
  final String status;
  final int? number;
  final bool cnc;
  final String? createdOn;
  final String? due;
  final String? decor;
  final double total;
  final double paid;
  final double debt;
  final String? toldOn;
}

/// One payment on a customer's card.
@immutable
class ClientPayment {
  const ClientPayment({
    required this.date,
    required this.order,
    required this.amount,
    this.method,
    this.cnc = false,
  });

  factory ClientPayment.fromJson(Map<String, dynamic> j) => ClientPayment(
    date: '${j['date'] ?? ''}',
    order: '${j['order']}',
    amount: _d(j['amount']),
    method: _s(j['method']),
    cnc: j['cnc'] == true,
  );

  final String date;
  final String order;
  final double amount;
  final String? method;
  final bool cnc;
}

/// What a customer has ordered in all, and owes.
@immutable
class ClientFigures {
  const ClientFigures({
    this.orders = 0,
    this.total = 0,
    this.paid = 0,
    this.debt = 0,
    this.average = 0,
    this.first,
    this.last,
  });

  factory ClientFigures.fromJson(Map<String, dynamic> j) => ClientFigures(
    orders: _i(j['orders']) ?? 0,
    total: _d(j['total']),
    paid: _d(j['paid']),
    debt: _d(j['debt']),
    average: _d(j['average']),
    first: _s(j['first']),
    last: _s(j['last']),
  );

  final int orders;
  final double total;
  final double paid;
  final double debt;
  final double average;
  final String? first;
  final String? last;
}

/// One customer on one page (owner, 18.11.2026).
@immutable
class ClientCard {
  const ClientCard({
    required this.customer,
    required this.name,
    this.phone,
    this.organization,
    this.tags = const [],
    this.filmCustomer = false,
    this.canFacades = false,
    this.canFilm = false,
    this.orders,
    this.payments = const [],
    this.figures,
    this.film,
  });

  factory ClientCard.fromJson(Map<String, dynamic> j) {
    final can = j['can'] is Map
        ? Map<String, dynamic>.from(j['can'] as Map)
        : const <String, dynamic>{};
    return ClientCard(
      customer: '${j['customer']}',
      name: '${j['name'] ?? j['customer']}',
      phone: Phone.prettyOrNull(_s(j['phone'])),
      organization: _s(j['organization']),
      tags: [for (final t in _l(j['tags'])) '$t'],
      filmCustomer: j['film_customer'] == true,
      canFacades: can['facades'] == true,
      canFilm: can['film'] == true,
      orders: j['orders'] is List
          ? [for (final o in _l(j['orders'])) ClientOrder.fromJson(_m(o))]
          : null,
      payments: [for (final p in _l(j['payments'])) ClientPayment.fromJson(_m(p))],
      figures: j['figures'] is Map
          ? ClientFigures.fromJson(_m(j['figures']))
          : null,
      film: j['film'] is Map ? FilmCustomer.fromJson(_m(j['film'])) : null,
    );
  }

  final String customer;
  final String name;
  final String? phone;
  final String? organization;
  final List<String> tags;
  final bool filmCustomer;
  final bool canFacades;
  final bool canFilm;

  /// Null when this person may not see facade orders and money.
  final List<ClientOrder>? orders;
  final List<ClientPayment> payments;
  final ClientFigures? figures;

  /// His card in the film department, when he buys film.
  final FilmCustomer? film;
}

/// Which message a row of «Кому написать» is.
enum ToWriteKind {
  ready,
  debt,
  filmDebt;

  static ToWriteKind parse(Object? raw) => switch (raw) {
    'debt' => debt,
    'film_debt' => filmDebt,
    _ => ready,
  };

  String get wire => switch (this) {
    ready => 'ready',
    debt => 'debt',
    filmDebt => 'film_debt',
  };
}

/// One customer to write to, with the words ready.
@immutable
class ToWriteRow {
  const ToWriteRow({
    required this.kind,
    required this.customer,
    required this.customerName,
    required this.text,
    this.order,
    this.number,
    this.cnc = false,
    this.phone,
    this.total = 0,
    this.debt = 0,
    this.readyOn,
    this.handedOverOn,
    this.remindedOn,
    this.reminders = 0,
    this.debtDays,
  });

  factory ToWriteRow.fromJson(Map<String, dynamic> j) => ToWriteRow(
    kind: ToWriteKind.parse(j['kind']),
    customer: '${j['customer']}',
    customerName: '${j['customer_name'] ?? ''}',
    text: '${j['text'] ?? ''}',
    order: _s(j['order']),
    number: _i(j['number']),
    cnc: j['cnc'] == true,
    phone: _s(j['phone']),
    total: _d(j['total']),
    debt: _d(j['debt']),
    readyOn: _s(j['ready_on']),
    handedOverOn: _s(j['handed_over_on']),
    remindedOn: _s(j['reminded_on']),
    reminders: _i(j['reminders']) ?? 0,
    debtDays: _i(j['debt_days']),
  );

  final ToWriteKind kind;
  final String customer;
  final String customerName;
  final String text;
  final String? order;
  final int? number;
  final bool cnc;

  /// As kept (+77015551234) — for WhatsApp; shown with [Phone.pretty].
  final String? phone;
  final double total;
  final double debt;
  final String? readyOn;
  final String? handedOverOn;
  final String? remindedOn;
  final int reminders;
  final int? debtDays;
}

/// «Кому написать» today.
@immutable
class ToWrite {
  const ToWrite({
    this.ready = const [],
    this.debts = const [],
    this.film = const [],
    this.afterDays = 3,
    this.repeatDays = 4,
  });

  factory ToWrite.fromJson(Map<String, dynamic> j) => ToWrite(
    ready: [for (final r in _l(j['ready'])) ToWriteRow.fromJson(_m(r))],
    debts: [for (final r in _l(j['debts'])) ToWriteRow.fromJson(_m(r))],
    film: [for (final r in _l(j['film'])) ToWriteRow.fromJson(_m(r))],
    afterDays: _i(j['after_days']) ?? 3,
    repeatDays: _i(j['repeat_days']) ?? 4,
  );

  final List<ToWriteRow> ready;
  final List<ToWriteRow> debts;
  final List<ToWriteRow> film;
  final int afterDays;
  final int repeatDays;

  int get count => ready.length + debts.length + film.length;
}

/// «Итоги дня»: the text the owner receives, and when.
@immutable
class DailySummary {
  const DailySummary({
    required this.text,
    this.enabled = false,
    this.hour = 20,
    this.sentOn,
  });

  factory DailySummary.fromJson(Map<String, dynamic> j) {
    final settings = j['settings'] is Map
        ? _m(j['settings'])
        : const <String, dynamic>{};
    return DailySummary(
      text: '${j['text'] ?? ''}',
      enabled: settings['enabled'] == true,
      hour: _i(settings['hour']) ?? 20,
      sentOn: _s(j['sent_on']),
    );
  }

  final String text;
  final bool enabled;
  final int hour;
  final String? sentOn;
}

/// A message's text: the owner's own and the default beside it.
typedef MessageTemplate = ({String text, String byDefault});

List<Object?> _l(Object? v) => v is List ? v : const [];

Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
