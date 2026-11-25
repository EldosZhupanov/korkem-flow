import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_invoice.dart';
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
    this.readyOn,
    this.handedOverOn,
    this.area = 0,
    this.stages = const [],
    this.debtDays,
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
    readyOn: _s(j['ready_on']),
    handedOverOn: _s(j['handed_over_on']),
    area: _d(j['area']),
    stages: [
      for (final x in _l(j['stages']))
        (key: '${_m(x)['key']}', done: _m(x)['done'] == true),
    ],
    debtDays: _i(j['debt_days']),
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
  final String? readyOn;
  final String? handedOverOn;

  /// The facades' square metres.
  final double area;

  /// Where it is in the shop: its stages in order, each done or not
  /// (owner, 21.11.2026 — «Принят» on every row said nothing).
  final List<({String key, bool done})> stages;

  /// How long its money has been owed, days; null when nothing is.
  final int? debtDays;

  bool get draft => status == 'draft';
  bool get handedOver => status == 'handed_over';
  bool get ready => status == 'ready';
}

/// One line of a customer's history (owner, 21.11.2026: «а истории заказа
/// нету ли тут?»): what happened, when, by whom, and of which kind.
enum ClientEventKind {
  order,
  money,
  message,
  note;

  static ClientEventKind parse(Object? v) => switch (v) {
    'money' => money,
    'message' => message,
    'note' => note,
    _ => order,
  };
}

@immutable
class ClientEvent {
  const ClientEvent({
    required this.at,
    required this.text,
    this.kind = ClientEventKind.order,
    this.by,
    this.order,
    this.number,
  });

  factory ClientEvent.fromJson(Map<String, dynamic> j) => ClientEvent(
    at: '${j['at'] ?? ''}',
    text: '${j['text'] ?? ''}',
    kind: ClientEventKind.parse(j['kind']),
    by: _s(j['by']),
    order: _s(j['order']),
    number: _i(j['number']),
  );

  /// `YYYY-MM-DD`, with ` HH:MM` when the moment is known.
  final String at;
  final String text;
  final ClientEventKind kind;
  final String? by;
  final String? order;
  final int? number;

  String get day => at.length >= 10 ? at.substring(0, 10) : at;
  String? get time => at.length >= 16 ? at.substring(11, 16) : null;
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
    this.terms = const MdfCustomerTerms(),
    this.limit = 0,
    this.invoices = const [],
    this.payerName = '',
    this.payerBin = '',
    this.vat = 0,
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
      payments: [
        for (final p in _l(j['payments'])) ClientPayment.fromJson(_m(p)),
      ],
      figures: j['figures'] is Map
          ? ClientFigures.fromJson(_m(j['figures']))
          : null,
      film: j['film'] is Map ? FilmCustomer.fromJson(_m(j['film'])) : null,
      terms: MdfCustomerTerms.fromJson(_m(j['terms'])),
      limit: _d(j['limit']),
      invoices: [
        for (final i in _l(j['invoices'])) MdfInvoice.fromJson(_m(i)),
      ],
      payerName: '${_m(j['payer'])['name'] ?? ''}',
      payerBin: '${_m(j['payer'])['bin'] ?? ''}',
      vat: _d(j['vat']).round(),
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

  /// His own prices and discount; the limit on what he may owe (his own,
  /// else the shop's), 0 — none.
  final MdfCustomerTerms terms;
  final double limit;

  /// «Счёт на долг» (owner, 25.11.2026): his invoices for what he owes,
  /// the oldest first.
  final List<MdfInvoice> invoices;

  /// Who pays for him, as his last invoice said, and the БИН; VAT on the
  /// shop's invoices, %.
  final String payerName;
  final String payerBin;
  final int vat;

  /// The invoices still waited for — open or paid in part.
  List<MdfInvoice> get waitedInvoices => [
    for (final i in invoices)
      if (i.waited) i,
  ];
}

/// «Акт сверки» (owner, 21.11.2026): what he was sold and paid between two
/// days, the balance before and after, and the two parties.
@immutable
class Reconciliation {
  const Reconciliation({
    required this.since,
    required this.until,
    required this.company,
    required this.payer,
    this.payerBin = '',
    this.requisites = const {},
    this.opening = 0,
    this.debit = 0,
    this.credit = 0,
    this.closing = 0,
    this.rows = const [],
  });

  factory Reconciliation.fromJson(Map<String, dynamic> j) => Reconciliation(
    since: '${j['since'] ?? ''}',
    until: '${j['until'] ?? ''}',
    company: '${j['company'] ?? ''}',
    payer: '${_m(j['payer'])['name'] ?? j['customer_name'] ?? ''}',
    payerBin: '${_m(j['payer'])['bin'] ?? ''}',
    requisites: {
      for (final e in _m(j['requisites']).entries)
        e.key: '${e.value ?? ''}'.trim(),
    },
    opening: _d(j['opening']),
    debit: _d(j['debit']),
    credit: _d(j['credit']),
    closing: _d(j['closing']),
    rows: [
      for (final r in _l(j['rows']))
        (
          date: '${_m(r)['date'] ?? ''}',
          text: '${_m(r)['text'] ?? ''}',
          debit: _d(_m(r)['debit']),
          credit: _d(_m(r)['credit']),
        ),
    ],
  );

  final String since;
  final String until;
  final String company;
  final String payer;
  final String payerBin;
  final Map<String, String> requisites;

  /// He owed before [since]; sold and paid in the period; owes after.
  final double opening;
  final double debit;
  final double credit;
  final double closing;
  final List<({String date, String text, double debit, double credit})> rows;
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
    this.morning = false,
    this.morningText,
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
      morning: settings['morning'] == true,
      morningText: _s(j['morning_text']),
    );
  }

  final String text;
  final bool enabled;
  final int hour;
  final String? sentOn;

  /// «Пора заказать» each morning (owner, 18.11.2026), and today's list —
  /// null when there is nothing to order or it is not this person's to see.
  final bool morning;
  final String? morningText;
}

/// A message's text: the owner's own and the default beside it.
typedef MessageTemplate = ({String text, String byDefault});

/// How a customer pays (owner, 25.11.2026): fast, as usual, drags it out —
/// or nothing to go by yet.
enum PayMark {
  fast,
  usual,
  slow;

  static PayMark? parse(Object? v) => switch ('$v') {
    'fast' => fast,
    'usual' => usual,
    'slow' => slow,
    _ => null,
  };
}

/// The periods a rating is made for.
enum RatingPeriod {
  months3('3m'),
  months12('12m'),
  all('all');

  const RatingPeriod(this.wire);

  final String wire;
}

/// One customer in «Рейтинг клиентов»: what his orders came to and his
/// part of it all, his class (A — the few who bring 80 %), how fast he
/// pays and what he owes now.
@immutable
class RatedCustomer {
  const RatedCustomer({
    required this.customer,
    required this.name,
    this.orders = 0,
    this.total = 0,
    this.paid = 0,
    this.debt = 0,
    this.share = 0,
    this.grade = 'C',
    this.payDays,
    this.paidOrders = 0,
    this.oldestDebtDays,
    this.mark,
    this.lastOrder,
  });

  factory RatedCustomer.fromJson(Map<String, dynamic> j) => RatedCustomer(
    customer: '${j['customer']}',
    name: '${j['name'] ?? j['customer']}',
    orders: _d(j['orders']).round(),
    total: _d(j['total']),
    paid: _d(j['paid']),
    debt: _d(j['debt']),
    share: _d(j['share']),
    grade: '${j['class'] ?? 'C'}',
    payDays: j['pay_days'] == null ? null : _d(j['pay_days']),
    paidOrders: _d(j['paid_orders']).round(),
    oldestDebtDays: j['oldest_debt_days'] == null
        ? null
        : _d(j['oldest_debt_days']).round(),
    mark: PayMark.parse(j['mark']),
    lastOrder: _s(j['last_order']),
  );

  final String customer;
  final String name;
  final int orders;
  final double total;
  final double paid;
  final double debt;

  /// His part of all the period's money, %.
  final double share;

  /// A, B or C.
  final String grade;

  /// Days from taking an order to paying it up, on average; null — none
  /// paid up yet.
  final double? payDays;
  final int paidOrders;
  final int? oldestDebtDays;
  final PayMark? mark;
  final String? lastOrder;
}

/// «Рейтинг клиентов»: everyone of the period, most money first.
@immutable
class CustomerRating {
  const CustomerRating({this.total = 0, this.customers = const []});

  factory CustomerRating.fromJson(Map<String, dynamic> j) => CustomerRating(
    total: _d(j['total']),
    customers: [
      for (final c in _l(j['customers'])) RatedCustomer.fromJson(_m(c)),
    ],
  );

  final double total;
  final List<RatedCustomer> customers;
}

List<Object?> _l(Object? v) => v is List ? v : const [];

Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
