import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_margin.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_ready.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_invoice_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_order_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

import '../../support/widget_harness.dart';

/// The owner's №1129 of 27.10.2026, as the server answers it.
Map<String, Object?> _card({
  String status = 'accepted',
  Map<String, String?> stages = const {},
}) => {
  'name': 'SAL-ORD-1129',
  'status': status,
  'overdue': false,
  'customer': 'Арман Қалдыбаев',
  'customer_name': 'Арман Қалдыбаев',
  'phone': '8 (777) 177-66-36',
  'created_on': '2026-10-27',
  'delivery_date': '2026-11-10',
  'head': {
    'thickness_mm': 16,
    'finish': 'ПВХ плёнка',
    'decor_top': 'Венге (Korkem)',
    'edge_profile': 'R3',
  },
  'lines': [
    {
      'height_mm': 130,
      'width_mm': 1040,
      'qty': 1,
      'milling': 'Тегіс 90°',
      'area_m2': 0.14,
      'rate_m2': 17000,
      'amount': 2380,
    },
    {
      'height_mm': 1577,
      'width_mm': 517,
      'qty': 2,
      'milling': 'Суреттегі үлгі',
      'area_m2': 1.63,
      'rate_m2': 19500,
      'amount': 31785,
    },
  ],
  'pieces': 3,
  'area_m2': 1.77,
  'total': 34165,
  'paid': 0,
  'debt': 34165,
  'payments': <Object>[],
  'stages': [
    for (final s in ['cut', 'mill', 'sand', 'vacuum'])
      {'stage': s, 'done_on': stages[s]},
  ],
};

/// A film never received: no price, no work booked.
class _Unpriced extends _FakeRepository {
  final priced = <(String, String, double)>[];

  @override
  Future<MdfMargin> margin(String order) async => MdfMargin.fromJson(const {
    'order': 'SAL-ORD-1129',
    'revenue': 68000,
    'material': 1398,
    'work': 0,
    'margin': 66602,
    'share': 0.98,
    'estimate': true,
    'missing': ['Плёнка ПВХ AL-01 Агератум'],
    'material_rows': [
      {
        'item': 'FILM-AL01',
        'title': 'Плёнка ПВХ AL-01 Агератум',
        'unit': 'м',
        'qty': 6.2,
        'cost': 0,
      },
      {
        'item': 'GLUE-JS',
        'title': 'JS group',
        'unit': 'кг',
        'qty': 0.46,
        'price': 3040,
        'cost': 1398,
      },
    ],
  });

  @override
  Future<MdfMargin> setMaterialPrice(
    String order,
    String item,
    double price,
  ) async {
    priced.add((order, item, price));
    return margin(order);
  }
}

class _FakeRepository implements MdfOrderRepository {
  final ticked = <(MdfStage, bool)>[];
  final added = <(MdfStage, bool)>[];
  final paid = <(double, String, String?)>[];
  final queries = <MdfListQuery>[];
  Map<String, String?> stages = {};

  @override
  Future<List<MdfOrderRow>> listing(MdfListQuery query) async {
    queries.add(query);
    return _rows;
  }

  @override
  Future<MdfOverview> overview() async => (
    overdue: 1,
    dueSoon: 2,
    ready: 3,
    debt: 58680.0,
    debtors: 1,
    bottleneck: (
      stage: MdfStage.sand,
      late: 1,
      lateTotal: 1,
      queueOrders: 1,
      queueM2: 1.77,
    ),
  );

  static final _rows = [
    MdfOrderRow.fromJson(const {
      'name': 'SAL-ORD-7',
      'status': 'ready',
      'created_on': '2026-10-20',
      'delivery_date': '2026-10-28',
      'customer_name': 'Ерлан',
      'area_m2': 2,
      'total': 34000,
      'paid': 34000,
      'debt': 0,
      'ready_days': 2,
      'stages': [
        {'stage': 'cut', 'done': true},
        {'stage': 'ready', 'done': true},
      ],
    }),
    MdfOrderRow.fromJson(const {
      'name': 'SAL-ORD-1129',
      'status': 'in_shop',
      'overdue': true,
      'created_on': '2026-10-27',
      'delivery_date': '2026-10-30',
      'customer_name': 'Арман Қалдыбаев',
      'phone': '8 (777) 177-66-36',
      'decor_top': 'Венге (Korkem)',
      'area_m2': 3.04,
      'total': 58680,
      'paid': 0,
      'debt': 58680,
      'stage': 'mill',
      'stages': [
        {'stage': 'cut', 'done': true},
        {'stage': 'mill', 'done': true},
        {'stage': 'sand', 'done': false, 'given': true},
        {'stage': 'vacuum', 'done': false, 'given': true},
        {'stage': 'ready', 'done': false, 'given': true},
      ],
      'waiting': 'sand',
      'days_left': -3,
      'tags': ['urgent'],
      'customer_tags': ['vip'],
    }),
  ];

  @override
  Future<MdfOrder> card(String name) async =>
      MdfOrder.fromJson({..._card(stages: stages), 'invoices': invoices});

  @override
  Future<MdfOrder> setStage(
    String order,
    MdfStage stage, {
    required bool done,
    String? worker,
    List<MdfCrewMember>? crew,
  }) async {
    ticked.add((stage, done));
    stages = {...stages, stage.name: done ? '2026-11-05' : null};
    return card(order);
  }

  @override
  Future<MdfOrder> extraStage(
    String order,
    MdfStage stage, {
    required bool on,
  }) async {
    added.add((stage, on));
    return card(order);
  }

  @override
  Future<void> addPayment(
    String order, {
    required double amount,
    required String method,
    String? bank,
    String? invoice,
  }) async {
    paid.add((amount, method, bank));
    paidBy.add(invoice);
  }

  /// The invoice each payment came by, if any.
  final paidBy = <String?>[];

  /// «Счёт на оплату»: what was asked for, and the order's invoices after.
  final invoiced = <(double, String?, String?, bool)>[];
  List<Map<String, Object?>> invoices = [];

  @override
  Future<({MdfInvoicePrint print, MdfOrder order})> issueInvoice(
    String order, {
    required double amount,
    required bool vat,
    String? payer,
    String? bin,
    String? dueOn,
  }) async {
    invoiced.add((amount, payer, bin, vat));
    final inv = <String, Object?>{
      'no': '7',
      'on': '2026-11-20',
      'due_on': '2099-01-01',
      'amount': amount,
      'payer': payer,
      'bin': bin,
      'vat': vat ? 16 : 0,
      'lines': [
        {
          'name': 'Предоплата',
          'qty': 1,
          'unit': 'усл.',
          'price': amount,
          'amount': amount,
        },
      ],
      'paid': 0,
      'state': 'open',
    };
    invoices = [inv];
    return (
      print: (
        invoice: MdfInvoice.fromJson(inv),
        requisites: <String, String>{},
      ),
      order: await card(order),
    );
  }

  /// The server's arithmetic, in short: the area rounded, times the price
  /// typed or the film's.
  /// What each repricing was asked for.
  final pricedLines = <List<MdfLineInput>>[];

  @override
  Future<MdfPricing> price({
    required List<MdfLineInput> lines,
    String? finish,
    double? defaultRate,
    Map<String, double> filmRates = const {},
    String? customer,
  }) async {
    pricedLines.add(lines);
    final priced = [
      for (final l in lines)
        () {
          final area = double.parse(
            (l.heightMm * l.widthMm * l.qty / 1e6).toStringAsFixed(2),
          );
          final rate = l.rate ?? filmRates[l.film] ?? 0;
          return MdfLine(
            heightMm: l.heightMm,
            widthMm: l.widthMm,
            qty: l.qty,
            areaM2: area,
            rateM2: rate,
            amount: (area * rate).roundToDouble(),
            film: l.film,
          );
        }(),
    ];
    return MdfPricing(
      lines: priced,
      pieces: priced.fold(0, (s, l) => s + l.qty),
      areaM2: priced.fold<double>(0, (s, l) => s + l.areaM2),
      total: priced.fold<double>(0, (s, l) => s + l.amount),
    );
  }

  final fixed = <(String, String, double, String)>[];
  final deleted = <(String, String)>[];
  final handed = <(String?, String?, String?)>[];
  final returned = <String>[];

  @override
  Future<MdfOrder> fixPayment(
    String order, {
    required String entry,
    required String reason,
    required double amount,
    required String method,
    String? bank,
  }) async {
    fixed.add((entry, reason, amount, method));
    return card(order);
  }

  @override
  Future<MdfOrder> deletePayment(
    String order, {
    required String entry,
    required String reason,
  }) async {
    deleted.add((entry, reason));
    return card(order);
  }

  @override
  Future<MdfOrder> handOver(
    String order, {
    String? comment,
    String? takenBy,
    String? takenPhone,
  }) async {
    handed.add((comment, takenBy, takenPhone));
    return card(order);
  }

  @override
  Future<MdfOrder> returnToWork(String order, String reason) async {
    returned.add(reason);
    return card(order);
  }

  /// №1129: 58 680 ₸, 20 000 of material by estimate, 5 000 of work.
  @override
  Future<MdfMargin> margin(String order) async => MdfMargin.fromJson(const {
    'order': 'SAL-ORD-1129',
    'revenue': 58680,
    'material': 20000,
    'work': 5000,
    'margin': 33680,
    'share': 0.574,
    'estimate': true,
    'material_rows': [
      {'title': 'МДФ 16 мм', 'unit': 'лист', 'qty': 0.6, 'cost': 12600},
    ],
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// SAL-ORD-2026-00013 as the owner saw it (09.11.2026): extras on a
/// position, a payment entered twice, every stage done.
class _Rich extends _FakeRepository {
  _Rich({this.status = 'ready', this.extra = const {}});

  final String status;
  final Map<String, Object?> extra;

  @override
  Future<MdfOrder> card(String name) async => MdfOrder.fromJson({
    ..._twoFilms(),
    'status': status,
    'paid': 294300,
    'debt': 0,
    'payments': const [
      {
        'entry': 'ACC-PAY-1',
        'amount': 147150,
        'date': '2026-11-09',
        'method': 'Перевод',
        'bank': 'Kaspi',
      },
      {
        'entry': 'ACC-PAY-2',
        'amount': 147150,
        'date': '2026-11-09',
        'method': 'Перевод',
        'bank': 'Kaspi',
      },
      {
        'entry': 'ACC-PAY-0',
        'amount': 5000,
        'date': '2026-11-08',
        'method': 'Наличные',
        'cancelled': true,
      },
    ],
    ...extra,
  });
}

Future<void> _pumpCard(WidgetTester tester, _FakeRepository repo) async {
  tester.view
    ..physicalSize = const Size(2400, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
      child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
    ),
  );
  await tester.pumpAndSettle();
}

/// A draft of two films, as Олжас Мухаметхан brought it (08.11.2026).
Map<String, Object?> _twoFilms() => {
  ..._card(status: 'draft'),
  'head': {
    'material': '16 мм МДФ',
    'film_rates': {'Белый Матовый': 17000, 'Палома': 18000},
  },
  'lines': [
    {
      'height_mm': 718,
      'width_mm': 500,
      'qty': 2,
      'area_m2': 0.72,
      'rate_m2': 17000,
      'amount': 12240,
      'film': 'Белый Матовый',
      'material': '16 мм МДФ',
    },
    {
      'height_mm': 300,
      'width_mm': 400,
      'qty': 2,
      'area_m2': 0.24,
      'rate_m2': 21000,
      'amount': 5040,
      'manual_rate': true,
      'film': 'Палома',
      'film_back': 'Графит',
      'material': '10 мм МДФ',
      'edge': 'R0',
      'patina': 'Золото',
    },
    {
      'height_mm': 500,
      'width_mm': 498,
      'qty': 5,
      'area_m2': 1.25,
      'rate_m2': 18000,
      'amount': 22500,
      'film': 'Палома',
      'material': '16 мм МДФ',
    },
  ],
};

class _TwoFilms extends _FakeRepository {
  @override
  Future<MdfOrder> card(String name) async => MdfOrder.fromJson(_twoFilms());
}

/// The shop is busy: ready only in nine working days (owner, 25.11.2026).
class _BusyShop extends _TwoFilms {
  final asked = <Map<String, double>>[];

  @override
  Future<MdfReadyEstimate> readyEstimate(
    Map<String, double> areas, {
    String? order,
  }) async {
    asked.add(areas);
    return MdfReadyEstimate(readyOn: mdfIso(earliest), days: 9, known: true);
  }

  static DateTime get earliest {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 10);
  }

  static DateTime get safe => earliest.add(const Duration(days: 1));

  final films = <Map<String, double>>[];

  @override
  Future<MdfDueOptions> dueOptions(
    Map<String, double> areas, {
    String? order,
    Map<String, double> films = const {},
  }) async {
    this.films.add(films);
    return MdfDueOptions(
      earliest: earliest,
      safe: safe,
      known: true,
      capacityM2: 10,
      films: [
        (
          decor: 'KZ13 Устюрт',
          freeM: 0,
          short: true,
          comesOn: earliest.subtract(const Duration(days: 3)),
          supplier: 'Kira',
        ),
      ],
      // The earliest day is full already: picking it warns.
      days: [(date: earliest, m2: 12, orders: 3)],
    );
  }
}

/// The first film is not on the shelf (owner, 18.11.2026).
class _FilmToBuy extends _FakeRepository {
  @override
  Future<MdfOrder> card(String name) async => MdfOrder.fromJson({
    ..._twoFilms(),
    'film_to_buy': const {
      'Белый Матовый': {'short': 3.1, 'from': 'MC Group'},
    },
  });
}

void main() {
  testWidgets('a textured film asks which way its pattern runs (26.11.2026)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _TwoFilms();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(repo),
          mdfDictionariesProvider.overrideWith(
            (ref) async => const MdfDictionaries({}, texturedFilms: {'Палома'}),
          ),
        ],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    // Палома is textured: its positions ask; Белый Матовый does not.
    expect(find.byKey(const ValueKey('mdfGrain:0')), findsNothing);
    expect(find.byKey(const ValueKey('mdfGrain:1')), findsOneWidget);
    expect(find.text('along height'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('mdfGrain:1')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('along width'), findsOneWidget);
    final sent = repo.pricedLines.last;
    expect(sent[1].toJson()['grain'], 'width');
    expect(sent[2].toJson().containsKey('grain'), isFalse);
    // The server's answer reads back.
    expect(
      MdfLine.fromJson(const {
        'height_mm': 140,
        'width_mm': 596,
        'qty': 2,
        'area_m2': 0.17,
        'rate_m2': 0,
        'amount': 0,
        'grain': 'width',
      }).grainWidth,
      isTrue,
    );
  });

  testWidgets('a film not on the shelf says so, and whom it comes from', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_FilmToBuy())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfFilmToBuy:0')), findsOneWidget);
    expect(find.textContaining('from MC Group'), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfFilmToBuy:1')), findsNothing);
  });

  testWidgets("one position's own board is the group's mark; of two, each", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    final ticks = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('mdfLineClientMdf:'),
    );
    // The first film has one position: no second «клиента» beside it.
    expect(ticks, findsNWidgets(2));
    await tester.tap(ticks.first);
    await tester.pumpAndSettle();
    expect(find.text("Customer's LMDF: 1 of 2"), findsOneWidget);
    await tester.tap(find.text("Customer's LMDF: 1 of 2"));
    await tester.pumpAndSettle();
    expect(find.text("Customer's LMDF: 1 of 2"), findsNothing);
    final both = tester.widgetList<FilterChip>(ticks);
    expect(both.every((c) => c.selected), isTrue);
  });

  testWidgets("the customer's own film and LMDF are marked on their group", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _TwoFilms();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    // A film group has no «paint» mark; the head has neither mark.
    expect(
      find.byKey(const ValueKey('mdfGroupTag:0:client_paint')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mdfOrderTag:client_film')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('mdfGroupTag:0:client_film')));
    await tester.tap(find.byKey(const ValueKey('mdfGroupTag:0:client_parts')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final sent = repo.pricedLines.last;
    expect(
      [for (final l in sent) (l.film, l.clientFilm, l.clientMdf)],
      [
        ('Белый Матовый', true, true),
        ('Палома', false, false),
        ('Палома', false, false),
      ],
    );
  });

  testWidgets('a draft of two films shows a group for each, with its totals', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfFilm:Белый Матовый')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfFilm:Палома')), findsOneWidget);
    // The film's price in the header; a price typed on a line stays its own.
    final rate = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfFilmRate:1')),
    );
    expect(rate.controller!.text, '18000');
    final own = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfRate:1')),
    );
    expect(own.controller!.text, '21000');
    final group = tester.widget<TextField>(
      find.byKey(const ValueKey('mdfRate:2')),
    );
    expect(group.controller!.text, isEmpty);
    // Positions keep one numbering through the groups; Палома: 2 + 5 pieces.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfFilmTotals:1'))).data,
      contains('7'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfFilmTotals:1'))).data,
      contains('1.49'),
    );
  });

  testWidgets("the due date by the shop's load, and a sooner one warned", (
    tester,
  ) async {
    final repo = _BusyShop();
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfDue')));
    await tester.pumpAndSettle();
    expect(repo.asked.single, isNotEmpty);
    expect(repo.films.single, isNotEmpty);
    // The film it waits for, and «надёжно» chosen: nothing to warn of.
    expect(find.byKey(const ValueKey('mdfDueFilm:KZ13 Устюрт')), findsOne);
    expect(find.textContaining('Kira'), findsOne);
    expect(find.byKey(const ValueKey('mdfDueWarn')), findsNothing);
    // «Впритык» lands on a full day: said, and still allowed.
    await tester.tap(find.byKey(const ValueKey('mdfDueByShop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfDueWarn')), findsOne);
    await tester.tap(find.byKey(const ValueKey('mdfDueSafe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfDueWarn')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfDuePick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfDueDialog')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mdfDue')),
        matching: find.textContaining(mdfDayOf(_BusyShop.safe)),
      ),
      findsOne,
    );
    expect(find.byKey(const ValueKey('mdfDueTooSoon')), findsNothing);
    // A day sooner than the shop can: warned in the month, then beside
    // the date.
    await tester.tap(find.byKey(const ValueKey('mdfDue')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    var soon = DateTime(now.year, now.month, now.day);
    if (soon.weekday == DateTime.sunday) {
      soon = soon.add(const Duration(days: 1));
    }
    final day = find.byKey(ValueKey('mdfDueDay:${mdfIso(soon)}'));
    for (var i = 0; i < 2 && day.evaluate().isEmpty; i++) {
      await tester.tap(find.byKey(const ValueKey('mdfDuePrev')));
      await tester.pumpAndSettle();
    }
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfDueWarn')), findsOne);
    await tester.tap(find.byKey(const ValueKey('mdfDuePick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfDueTooSoon')), findsOne);
  });

  testWidgets('the due date falls back to the calendar when the shop is '
      'not answering', (tester) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfDue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfDueCalendar')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOne);
  });

  testWidgets('a row has its R, R3 by default, and its extras under it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    String? edgeOf(int i) => tester
        .widget<DropdownButtonFormField<String?>>(
          find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String?> &&
                '${w.key}'.contains('mdfLineEdge:$i:'),
          ),
        )
        .initialValue;
    // A film group picks from the catalogue, not from the old colour list.
    expect(find.byKey(const ValueKey('filmPick:0')), findsOneWidget);
    expect(find.byKey(const ValueKey('dict:group:0')), findsNothing);
    expect(edgeOf(0), 'R3'); // nobody said otherwise
    expect(edgeOf(1), 'R0'); // a sharp corner
    // Position 2 has its back side and its patina, each a chip with ✕.
    expect(find.byKey(const ValueKey('mdfExtra:back:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfExtra:patina:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfExtra:back:0')), findsNothing);
    // The patina and the back side open their lists from the chip.
    expect(find.byKey(const ValueKey('dict:patina:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dict:back:1')), findsOneWidget);
    // «+ доп.» → Примечание on position 1.
    await tester.tap(find.byKey(const ValueKey('mdfMore:0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfMore:note')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfExtra:note:0')), findsOneWidget);
    // ✕ takes the patina off position 2.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('mdfExtra:patina:1')),
        matching: find.byKey(const ValueKey('mdfExtraRemove')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfExtra:patina:1')), findsNothing);
    expect(find.byKey(const ValueKey('mdfExtra:back:1')), findsOneWidget);
    // The order's tags are chips in the head.
    await tester.tap(find.byKey(const ValueKey('mdfOrderTag:urgent')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('mdfOrderTag:urgent')))
          .selected,
      isTrue,
    );
    // The edge list is edited from its own drop-down (owner, 26.11.2026:
    // «почему тут не добавляются материалы и размеры?»); closing it leaves
    // the position's edge as it was.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String?> &&
            '${w.key}'.contains('mdfLineEdge:0:'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfLineEdge:0:editList')).last);
    await tester.pumpAndSettle();
    expect(find.byType(MdfDictionaryDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(MdfDictionaryDialog))).pop();
    await tester.pumpAndSettle();
    expect(edgeOf(0), 'R3');
    expect(find.text('R3'), findsWidgets);
  });

  test('tags, a radius and a patina come and go as the server has them', () {
    final order = MdfOrder.fromJson({
      ..._twoFilms(),
      'customer_tags': const ['vip', 'prepay_only', 'nonsense'],
      'head': const {
        'tags': ['urgent'],
      },
    });
    expect(order.tags, [MdfOrderTag.urgent]);
    expect(order.customerTags, [
      MdfCustomerTag.vip,
      MdfCustomerTag.prepayOnly,
    ]);
    expect(order.lines[1].edge, 'R0');
    expect(order.lines[1].patina, 'Золото');
    expect(const MdfHead(tags: [MdfOrderTag.rework]).toJson(), {
      'tags': ['rework'],
    });
    expect(
      const MdfLineInput(
        heightMm: 1,
        widthMm: 1,
        qty: 1,
        edge: 'R0',
        patina: 'Золото',
      ).toJson(),
      containsPair('edge', 'R0'),
    );
  });

  test('one colour name under two coatings is two groups', () {
    final order = MdfOrder.fromJson({
      ..._card(),
      'lines': const [
        {'height_mm': 500, 'width_mm': 500, 'qty': 1, 'coating': 'pvc'},
        {
          'height_mm': 500,
          'width_mm': 500,
          'qty': 1,
          'coating': 'paint',
          'film': 'RAL 9010',
        },
        {'height_mm': 400, 'width_mm': 400, 'qty': 1, 'coating': 'pvc'},
      ],
    });
    final groups = mdfFilmGroups(order.lines);
    expect(
      [for (final g in groups) (g.coating, g.film)],
      [
        (MdfCoating.pvc, null),
        (MdfCoating.paint, 'RAL 9010'),
      ],
    );
    expect(groups.first.pieces, 2);
    expect(
      const MdfLineInput(
        heightMm: 1,
        widthMm: 1,
        qty: 1,
        coating: MdfCoating.paint,
      ).toJson()['coating'],
      'paint',
    );
  });

  testWidgets("a new order's first block asks its type; a type can change", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const MdfOrderScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // No ПВХ by default: the manager may start with paint.
    for (final c in MdfCoating.values) {
      expect(find.byKey(ValueKey('mdfGroupType:0:${c.name}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('mdfGroupType:0:paint')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mdfGroupCoating:0:paint')),
      findsOneWidget,
    );
    // A paint block says its finish, for the paint shop (15.11.2026).
    await tester.tap(find.byKey(const ValueKey('mdfGroupGloss:0:null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gloss').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfGroupGloss:0:gloss')), findsOne);
    // And changed from the header: no colour yet, so no question.
    await tester.tap(find.byKey(const ValueKey('mdfGroupCoating:0:paint')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfGroupTypeTo:raw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfGroupCoating:0:raw')), findsOneWidget);
  });

  testWidgets("changing a coloured block's type asks, then clears the colour", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfGroupCoating:0:pvc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfGroupTypeTo:paint')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfCoatingSwitchYes')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mdfGroupCoating:0:paint')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mdfGroupCoating:1:pvc')), findsOneWidget);
  });

  testWidgets('«+ Добавить покрытие» asks the type first', (tester) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const MdfOrderScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The three types are buttons of their own — no window to answer first
    // (owner, 20.11.2026).
    for (final c in MdfCoating.values) {
      expect(find.byKey(ValueKey('mdfAdd:${c.name}')), findsOneWidget);
    }
    // A raw facade has no colour: no list to pick from, the group is made.
    await tester.tap(find.byKey(const ValueKey('mdfAdd:raw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfGroupCoating:0:raw')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfFilmPick:0:0')), findsNothing);
    expect(find.byKey(const ValueKey('dict:group:0')), findsNothing);
  });

  testWidgets('a group copied into another coating: the same positions', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(_TwoFilms())],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfLineFilm:3')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfGroupCopy:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfCopyTo:raw')));
    await tester.pumpAndSettle();
    // «Палома»'s two positions, now raw too, as a third group; the sizes
    // and the counts came along, a back film did not.
    expect(find.byKey(const ValueKey('mdfGroupCoating:2:raw')), findsOne);
    expect(find.byKey(const ValueKey('mdfLineFilm:3')), findsOne);
    expect(find.byKey(const ValueKey('mdfLineFilm:4')), findsOne);
    expect(find.byKey(const ValueKey('mdfLineFilm:5')), findsNothing);
  });

  test('dates read day.month.year; a week ahead skips a Sunday', () {
    expect(mdfDay('2026-11-09'), '09.11.2026');
    expect(mdfDay('2026-11-09', year: false), '09.11');
    expect(mdfDay('soon'), 'soon');
    // Monday 09.11.2026 + 7 = Monday 16.11.
    expect(mdfDueIn(DateTime(2026, 11, 9)), DateTime(2026, 11, 16));
    // Monday + 6 = Sunday 15.11 → Monday 16.11.
    expect(mdfDueIn(DateTime(2026, 11, 9), days: 6), DateTime(2026, 11, 16));
    expect(mdfIso(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('the positions fall into film groups in the order films appear', () {
    final order = MdfOrder.fromJson(_twoFilms());
    final groups = mdfFilmGroups(order.lines);
    expect([for (final g in groups) g.film], ['Белый Матовый', 'Палома']);
    expect([for (final (n, _) in groups.last.lines) n], [2, 3]);
    expect(groups.last.pieces, 7);
    expect(groups.last.areaM2, 1.49);
    expect(groups.last.amount, 27540);
    expect(order.head.filmRates['Палома'], 18000);
    expect(order.lines[1].filmBack, 'Графит');
  });

  test('a card reads the stages its finish has, in order', () {
    final order = MdfOrder.fromJson(_card(stages: {'cut': '2026-11-01'}));
    expect(order.stages.keys, [
      MdfStage.cut,
      MdfStage.mill,
      MdfStage.sand,
      MdfStage.vacuum,
    ]);
    expect(order.stages[MdfStage.cut], '2026-11-01');
    expect(order.stages[MdfStage.mill], isNull);
  });

  test('the head sends only what was filled in', () {
    expect(const MdfHead(finish: 'ПВХ плёнка', thicknessMm: 16).toJson(), {
      'thickness_mm': 16,
      'finish': 'ПВХ плёнка',
    });
  });

  testWidgets('a new or just accepted order stands on top: «Только что»', (
    tester,
  ) async {
    // Owner, 26.11.2026: №00040 sank under 22 overdue ones and looked lost.
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfSection:recent')), findsNothing);
    ProviderScope.containerOf(
      tester.element(find.byType(MdfOrdersScreen)),
    ).read(mdfRecentOrdersProvider.notifier).add('SAL-ORD-1129');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfSection:recent')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mdfRecent:SAL-ORD-1129')),
      findsOneWidget,
    );
    // Still in its own section below.
    expect(find.byKey(const ValueKey('mdfRow:SAL-ORD-1129')), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('mdfRecentClear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfSection:recent')), findsNothing);
  });

  testWidgets('the list names the bottleneck, jumps to a section, goes one '
      'line an order, and acts on a row (26.11.2026)', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The cause, not the rows: the late ones wait for sanding.
    expect(find.byKey(const ValueKey('mdfBottleneck')), findsOneWidget);
    expect(find.textContaining('1 of 1 late orders'), findsOneWidget);
    // The sections as chips.
    expect(find.byKey(const ValueKey('mdfJump:overdue')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfJump:ready')));
    await tester.pumpAndSettle();
    // Under the pointer: the row's own actions.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('mdfRow:SAL-ORD-1129'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mdfRowPay:SAL-ORD-1129')),
      findsOneWidget,
    );
    // The bar itself: a tap ticks the stage (owner, 26.11.2026, variant Б).
    await tester.tap(find.byKey(const ValueKey('mdfBar:SAL-ORD-1129:sand')));
    await tester.pumpAndSettle();
    expect(repo.ticked.last, (MdfStage.sand, true));
    expect(find.byKey(const ValueKey('mdfStageDoneSnack')), findsOneWidget);
    // A later one asks to tick those before it — stages are not skipped.
    await tester.tap(find.byKey(const ValueKey('mdfBar:SAL-ORD-1129:ready')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfStageManyYes')));
    await tester.pumpAndSettle();
    expect(repo.ticked.skip(1).toList(), [
      (MdfStage.sand, true),
      (MdfStage.vacuum, true),
      (MdfStage.ready, true),
    ]);
    // A done one asks before the tick comes off.
    await tester.tap(find.byKey(const ValueKey('mdfBar:SAL-ORD-1129:cut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfStageUndoYes')));
    await tester.pumpAndSettle();
    expect(repo.ticked.last, (MdfStage.cut, false));
    // One line an order.
    await tester.tap(find.byKey(const ValueKey('mdfDense')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfRow:SAL-ORD-1129')), findsOneWidget);
    // «Показать просроченные» narrows the list.
    await tester.tap(find.byKey(const ValueKey('mdfBottleneckShow')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.overdue, isTrue);
  });

  testWidgets('the list shows an overdue order and its debt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfRow:SAL-ORD-1129')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mdfOverdue:SAL-ORD-1129')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mdfDebt:SAL-ORD-1129')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfTag:urgent')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfCustomerTag:vip')), findsOneWidget);
  });

  testWidgets('the list reads top-down by what burns; a figure narrows it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The late order stands above the ready one, whatever the server's order.
    final late = tester.getTopLeft(
      find.byKey(const ValueKey('mdfSection:overdue')),
    );
    final ready = tester.getTopLeft(
      find.byKey(const ValueKey('mdfSection:ready')),
    );
    expect(late.dy, lessThan(ready.dy));
    // Where it is, and how late.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mdfNowAt:SAL-ORD-1129')))
          .data,
      'now: Sanding',
    );
    expect(find.text('3 d late'), findsOneWidget);
    expect(find.text('ready 2 d'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mdfKpi:ready:value')))
          .data,
      '3',
    );
    // A figure tapped asks the server for those orders; tapped again, all.
    await tester.tap(find.byKey(const ValueKey('mdfKpi:overdue')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.overdue, isTrue);
    expect(find.byKey(const ValueKey('mdfSection:overdue')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfKpi:dueSoon')));
    await tester.pumpAndSettle();
    expect(
      (repo.queries.last.overdue, repo.queries.last.dueSoon),
      (
        false,
        true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mdfKpi:dueSoon')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.dueSoon, isFalse);
  });

  testWidgets('a tag filter asks the server for that tag', (tester) async {
    tester.view
      ..physicalSize = const Size(2400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.queries.last.tag, isNull);
    await tester.tap(find.byKey(const ValueKey('mdfFilter:urgent')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.tag, 'urgent');
    await tester.tap(find.byKey(const ValueKey('mdfFilter:furnitureMaker')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.tag, 'furniture_maker');
  });

  test('«готово» is a stage, after the vacuum', () {
    expect(MdfStage.parse('ready'), MdfStage.ready);
    expect(MdfStage.values.last, MdfStage.ready);
    expect(MdfStage.extra, [MdfStage.paint, MdfStage.vacuum]);
    final order = MdfOrder.fromJson({
      ..._card(),
      'stages': const [
        {'stage': 'cut'},
        {'stage': 'paint', 'extra': true},
        {'stage': 'ready'},
      ],
    });
    expect(order.extraStages, {MdfStage.paint});
  });

  testWidgets('«+ этап» adds paint to a film order for a rework', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfAddStage')));
    await tester.pumpAndSettle();
    // A film order has its vacuum: only paint is offered.
    expect(find.byKey(const ValueKey('mdfAddStage:vacuum')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfAddStage:paint')));
    await tester.pumpAndSettle();
    expect(repo.added, [(MdfStage.paint, true)]);
  });

  testWidgets('a payment in cash asks for no bank; a transfer does', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfAddPayment')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dict:bank')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentMethod:Наличные')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dict:bank')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('mdfPaymentAmount')),
      '5000',
    );
    // The save button wakes up once there is an amount.
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mdfPaymentSave')));
    await tester.pumpAndSettle();
    expect(repo.paid, [(5000.0, 'Наличные', null)]);
  });

  testWidgets('a change with nothing changed asks no reason', (tester) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfChangeOrder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfSaveChange')));
    await tester.pumpAndSettle();
    // Straight back to the card: no dialog, nothing sent.
    expect(find.byKey(const ValueKey('mdfChangeReasonField')), findsNothing);
    expect(find.byKey(const ValueKey('mdfChangeOrder')), findsOneWidget);

    // A real change: the dialog says what, and a ready reason is enough.
    await tester.tap(find.byKey(const ValueKey('mdfChangeOrder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mdfQ:0')), '9');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfSaveChange')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfChangesList')), findsOneWidget);
    expect(find.textContaining('→ 9'), findsOneWidget);
    final yes = find.byKey(const ValueKey('mdfChangeReasonYes'));
    expect(tester.widget<FilledButton>(yes).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mdfReasonChip:0')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(yes).onPressed, isNotNull);
  });

  testWidgets('just accepted: «Заказ принят», the prepayment in one tap, '
      '«Изменить заказ» on top', (tester) async {
    // Owner, 26.11.2026: «назад» from an accepted order is the list; the
    // card offers what comes next instead.
    final repo = _FakeRepository();
    await _pumpCard(tester, repo);
    expect(find.byKey(const ValueKey('mdfAcceptedBanner')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MdfOrderScreen)),
    );
    container.read(mdfJustAcceptedProvider.notifier).add('SAL-ORD-1129');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfAcceptedBanner')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfAcceptedNext')), findsOneWidget);
    // «Изменить заказ» stands above the positions now.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('mdfChangeOrder'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('mdfAddPayment'))).dy,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mdfAcceptedPay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfPaymentAmount')), findsOneWidget);
    // No prepayment rule set: the window says where to set it.
    expect(find.byKey(const ValueKey('mdfPrepaySet')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('mdfPaymentAmount'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfAcceptedClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfAcceptedBanner')), findsNothing);
  });

  testWidgets('leaving a new order with sizes typed asks first', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(2400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MdfOrderScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Nothing typed: «назад» simply goes back.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mdfH:0')), '700');
    await tester.enterText(find.byKey(const ValueKey('mdfW:0')), '400');
    await tester.enterText(find.byKey(const ValueKey('mdfQ:0')), '2');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfLeaveSave')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfLeaveYes')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the manager ticks a stage on the card', (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfStage:paint')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfStage:cut')));
    await tester.pumpAndSettle();
    expect(repo.ticked, [(MdfStage.cut, true)]);
    // Day.month, the way the shop reads it (09.11.2026).
    expect(find.textContaining('05.11'), findsOneWidget);
  });

  testWidgets("a position's back side and patina sit under its coating; "
      'a note gets a row of its own', (tester) async {
    final noted = [
      for (final l in _twoFilms()['lines']! as List<Object?>)
        {...l! as Map<String, Object?>},
    ];
    noted[0]['note'] = 'Продолжение узора';
    await _pumpCard(tester, _Rich(extra: {'lines': noted}));
    // Position 2's back side and patina are in its coating cell, not a row.
    expect(find.textContaining('Графит'), findsOneWidget);
    expect(find.textContaining('Золото'), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfLineExtras:2')), findsNothing);
    // Position 1's note is a row under it.
    expect(find.byKey(const ValueKey('mdfLineExtras:1')), findsOneWidget);
    // Each coating's name heads its group.
    expect(find.byKey(const ValueKey('mdfGroupHeadText:0')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfGroupHeadText:1')), findsOneWidget);
    expect(find.textContaining('Продолжение узора'), findsOneWidget);
  });

  testWidgets('a film group says how much film it takes on the press', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _Rich(
        extra: {
          'press': {
            'Белый Матовый': {
              'film_m': 8.3,
              'layout_m': 8.3,
              'plain_m': 9.3,
              'loads': [3.1, 3.1, 2.1],
            },
          },
        },
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('mdfGroupFilm:0')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Film 8,3 m · 3 loads · smart layout −1,0 m',
    );
    // Палома has no layout yet: no metres, no map button.
    expect(find.byKey(const ValueKey('mdfGroupFilm:1')), findsNothing);
    expect(find.byKey(const ValueKey('mdfGroupPress:0')), findsOneWidget);
    expect(
      mdfFilmPressText(
        const MdfFilmPress(filmM: 9, loads: [3.1, 3.1, 3.1], corrected: true),
        await AppLocalizations.delegate.load(const Locale('ru')),
      ),
      'Плёнка 9,0 м · загрузок 3 · поправлено вручную',
    );
  });

  testWidgets('the layout button opens the press layout (14.11.2026)', (
    tester,
  ) async {
    // The button is drawn past its narrow cell; a tap on it once went
    // nowhere. The group's row takes it now.
    tester.view
      ..physicalSize = const Size(2400, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: MdfOrderScreen(name: 'SAL-ORD-1129')),
        ),
        GoRoute(
          path: Routes.pressLayout,
          builder: (_, state) =>
              Text('layout of ${state.pathParameters['order']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(
            _Rich(
              extra: {
                'press': {
                  'Белый Матовый': {
                    'film_m': 8.3,
                    'layout_m': 8.3,
                    'plain_m': 9.3,
                    'loads': [3.1, 3.1, 2.1],
                  },
                },
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfGroupPress:0')));
    await tester.pumpAndSettle();
    expect(find.text('layout of SAL-ORD-1129'), findsOneWidget);
  });

  testWidgets('a payment is fixed with a reason; a cancelled one has no menu', (
    tester,
  ) async {
    final repo = _Rich();
    await _pumpCard(tester, repo);
    expect(find.byKey(const ValueKey('mdfPaymentMenu:2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentMenu:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfPaymentDelete:1')));
    await tester.pumpAndSettle();
    final yes = find.byKey(const ValueKey('mdfPaymentDeleteYes'));
    expect(tester.widget<FilledButton>(yes).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mdfPayReason:3')));
    await tester.pumpAndSettle();
    await tester.tap(yes);
    await tester.pumpAndSettle();
    expect(repo.deleted.single.$1, 'ACC-PAY-2');

    await tester.tap(find.byKey(const ValueKey('mdfPaymentMenu:0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfPaymentFix:0')));
    await tester.pumpAndSettle();
    // The payment's own figures to start from.
    expect(find.text('147150'), findsOneWidget);
    final save = find.byKey(const ValueKey('mdfPaymentSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('mdfPaymentAmount')),
      '140000',
    );
    await tester.tap(find.byKey(const ValueKey('mdfPayReason:0')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.fixed.single, (
      'ACC-PAY-1',
      'Wrong amount',
      140000.0,
      'Перевод',
    ));
  });

  testWidgets('a hand-over asks the pieces counted and who takes it', (
    tester,
  ) async {
    final repo = _Rich();
    await _pumpCard(tester, repo);
    await tester.tap(find.byKey(const ValueKey('mdfHandOver')));
    await tester.pumpAndSettle();
    final yes = find.byKey(const ValueKey('mdfHandOverYes'));
    expect(tester.widget<FilledButton>(yes).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mdfHandOverCounted')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(yes).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('mdfTakenOther')));
    await tester.pumpAndSettle();
    // Someone else: a name is needed.
    expect(tester.widget<FilledButton>(yes).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('mdfTakenName')), 'Ерлан');
    await tester.enterText(
      find.byKey(const ValueKey('mdfTakenPhone')),
      '87011234567',
    );
    await tester.pumpAndSettle();
    await tester.tap(yes);
    await tester.pumpAndSettle();
    // Typed any way, it reads one way (owner, 18.11.2026).
    expect(repo.handed.single, (null, 'Ерлан', '+7 (701) 123-45-67'));
    expect(find.text('Order handed over'), findsOneWidget);
  });

  testWidgets('a handed-over order says who took it and goes back to work', (
    tester,
  ) async {
    final repo = _Rich(
      status: 'handed_over',
      extra: {
        'debt': 1000,
        'handed_over_on': '2026-11-09',
        'handed_over_by': 'Олжас',
        'taken_by': 'Ерлан',
        'taken_phone': '87011234567',
      },
    );
    await _pumpCard(tester, repo);
    expect(find.byKey(const ValueKey('mdfHandedOverBanner')), findsOneWidget);
    expect(find.textContaining('09.11.2026'), findsWidgets);
    expect(find.textContaining('Ерлан, 87011234567'), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfHandedWithDebt')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfHandOver')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfReturnToWork')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mdfReason')), 'Скол');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done').last);
    await tester.pumpAndSettle();
    expect(repo.returned, ['Скол']);
  });

  testWidgets('a payment in cash and a transfer at once; the rest fills in', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await _pumpCard(tester, repo);
    await tester.tap(find.byKey(const ValueKey('mdfAddPayment')));
    await tester.pumpAndSettle();
    // The order's total, what is paid and what is left, on top.
    expect(find.byKey(const ValueKey('mdfPaymentFigures')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentMethod:Наличные')));
    await tester.enterText(
      find.byKey(const ValueKey('mdfPaymentAmount')),
      '10000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfPaymentAddPart')));
    await tester.pumpAndSettle();
    // 34 165 owed, 10 000 in cash: the transfer takes the rest.
    expect(find.text('24165'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentSave')));
    await tester.pumpAndSettle();
    expect(repo.paid, [
      (10000.0, 'Наличные', null),
      (24165.0, 'Перевод', null),
    ]);
  });

  testWidgets('an invoice to pay: half before the work, then paid by it', (
    tester,
  ) async {
    final repo = _FakeRepository();
    final sent = <MdfInvoicePrint>[];
    tester.view
      ..physicalSize = const Size(2400, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfOrderRepositoryProvider.overrideWithValue(repo),
          filmDeptRepositoryProvider.overrideWithValue(_Requisites()),
          mdfInvoiceSendProvider.overrideWithValue(
            (order, paper, l10n) async => sent.add(paper),
          ),
        ],
        child: harness(const MdfOrderScreen(name: 'SAL-ORD-1129')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfInvoice')));
    await tester.pumpAndSettle();
    // Nothing paid yet: half of 34 165 before the work.
    await tester.tap(find.byKey(const ValueKey('mdfInvoiceSum:half')));
    await tester.enterText(
      find.byKey(const ValueKey('mdfInvoicePayer')),
      'ТОО «Мебель-Юг»',
    );
    await tester.enterText(find.byKey(const ValueKey('mdfInvoiceBin')), '123');
    await tester.pumpAndSettle();
    final make = find.byKey(const ValueKey('mdfInvoiceMake'));
    expect(tester.widget<FilledButton>(make).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('mdfInvoiceBin')),
      '123456789012',
    );
    await tester.tap(find.byKey(const ValueKey('mdfInvoiceVat')));
    await tester.pumpAndSettle();
    await tester.tap(make);
    await tester.pumpAndSettle();
    expect(repo.invoiced, [
      (17083.0, 'ТОО «Мебель-Юг»', '123456789012', true),
    ]);
    expect(sent.single.invoice.no, '7');
    // On the card: waited for.
    expect(find.byKey(const ValueKey('mdfInvoice:7')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('mdfInvoiceState:7'))).data,
      startsWith('awaiting payment by'),
    );
    // Paid by it: the sum is the invoice's, the method a transfer.
    await tester.tap(find.byKey(const ValueKey('mdfAddPayment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfPayInvoice:7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mdfPaymentSave')));
    await tester.pumpAndSettle();
    expect(repo.paid, [(17083.0, 'Перевод', null)]);
    expect(repo.paidBy, ['7']);
  });

  testWidgets('a payment starts at what is left; cash shows the change', (
    tester,
  ) async {
    // Owner, 26.11.2026: «полноценная сумма по умолчанию, при
    // необходимости менеджер сам исправит».
    final repo = _FakeRepository();
    await _pumpCard(tester, repo);
    await tester.tap(find.byKey(const ValueKey('mdfAddPayment')));
    await tester.pumpAndSettle();
    final amount = find.byKey(const ValueKey('mdfPaymentAmount'));
    expect(tester.widget<TextField>(amount).controller!.text, '34165');
    expect(find.byKey(const ValueKey('payQuick:all')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentMethod:Наличные')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payCashGiven')),
      '40000',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('payCashChange')))
          .data!
          .replaceAll(RegExp('[^0-9]'), ''),
      '5835',
    );
    await tester.tap(find.byKey(const ValueKey('mdfPaymentSave')));
    await tester.pumpAndSettle();
    expect(repo.paid, [(34165.0, 'Наличные', null)]);
  });

  testWidgets('more than is owed asks to be called an overpayment', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await _pumpCard(tester, repo);
    await tester.tap(find.byKey(const ValueKey('mdfAddPayment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mdfPaymentAmount')),
      '68330',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfPaymentOver')), findsOneWidget);
    final save = find.byKey(const ValueKey('mdfPaymentSave'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('mdfPaymentOverOk')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.paid, [(68330.0, 'Перевод', null)]);
  });

  testWidgets('the card shows what the order earned, and what it leaves out', (
    tester,
  ) async {
    await _pumpCard(tester, _Rich());
    final value = find.byKey(const ValueKey('mdfMarginValue'));
    expect(tester.widget<Text>(value).data, contains('57%'));
    expect(find.byKey(const ValueKey('mdfMarginEstimate')), findsOneWidget);
    expect(find.byKey(const ValueKey('mdfMarginNotCounted')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mdfMargin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mdfMarginNotCounted')), findsOneWidget);
    expect(find.textContaining('МДФ 16 мм'), findsOneWidget);
  });

  testWidgets(
    'a material with no price: the margin is not exact, priced here',
    (
      tester,
    ) async {
      final repo = _Unpriced();
      await _pumpCard(tester, repo);
      final value = find.byKey(const ValueKey('mdfMarginValue'));
      expect(tester.widget<Text>(value).data, contains('≈'));
      expect(find.byKey(const ValueKey('mdfMarginUnsure')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mdfMargin')));
      await tester.pumpAndSettle();
      // Work booked as nothing: the rates are one tap away.
      expect(find.byKey(const ValueKey('mdfMarginRates')), findsOneWidget);
      final set = find.byKey(const ValueKey('mdfMarginPrice:FILM-AL01'));
      await tester.ensureVisible(set);
      await tester.tap(set);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mdfMarginPriceField')),
        '1 450',
      );
      await tester.tap(find.byKey(const ValueKey('mdfMarginPriceSave')));
      await tester.pumpAndSettle();
      expect(repo.priced, [('SAL-ORD-1129', 'FILM-AL01', 1450.0)]);
    },
  );

  test('a finish goes to the server for a paint line only', () {
    const paint = MdfLineInput(
      heightMm: 700,
      widthMm: 400,
      qty: 1,
      coating: MdfCoating.paint,
      gloss: MdfGloss.metallic,
    );
    expect(paint.toJson()['gloss'], 'metallic');
    const film = MdfLineInput(
      heightMm: 700,
      widthMm: 400,
      qty: 1,
      coating: MdfCoating.pvc,
      gloss: MdfGloss.metallic,
    );
    expect(film.toJson().containsKey('gloss'), isFalse);
  });
}

/// The factory's requisites, filled in.
class _Requisites implements FilmDeptRepository {
  @override
  Future<Map<String, String>> requisites() async =>
      filmRequisitesOf(const {'name': 'ТОО «KORKEM»', 'bin': '123456789012'});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
