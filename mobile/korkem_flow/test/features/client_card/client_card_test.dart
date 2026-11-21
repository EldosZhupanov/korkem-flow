import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/client_card/presentation/client_card_screen.dart';
import 'package:korkem_flow/features/client_card/presentation/reconciliation.dart';
import 'package:korkem_flow/features/client_card/presentation/to_write_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

import '../../support/widget_harness.dart';

const Map<String, Object> _ready = {
  'kind': 'ready',
  'order': 'SAL-ORD-2026-00245',
  'number': 245,
  'customer': 'CUST-1',
  'customer_name': 'Ерлан Абенов',
  'phone': '+77015551234',
  'total': 68000,
  'debt': 18000,
  'ready_on': '2026-11-17',
  'text': 'Здравствуйте, Ерлан Абенов! Ваш заказ № 245 готов, можно забирать.',
};

const Map<String, Object> _debt = {
  'kind': 'debt',
  'order': 'SAL-ORD-2026-00231',
  'number': 231,
  'customer': 'CUST-2',
  'customer_name': 'Айгуль Сапарова',
  'phone': '+77025550000',
  'debt': 50000,
  'handed_over_on': '2026-11-10',
  'reminded_on': '2026-11-12',
  'reminders': 1,
  'text':
      'Здравствуйте, Айгуль Сапарова! Напоминаем об оплате по заказу № 231.',
};

class _Fake implements ClientCardRepository {
  final paid = <(double, String)>[];
  final notes = <String>[];
  int reminders = 0;
  final acts = <(String?, String?)>[];

  @override
  Future<Reconciliation> reconciliation(
    String customer, {
    String? since,
    String? until,
  }) async {
    acts.add((since, until));
    return _act;
  }

  final marked = <(ToWriteKind, String?)>[];
  final saved = <(ToWriteKind, String)>[];
  bool toldReady = false;

  @override
  Future<ToWrite> todo() async => ToWrite.fromJson({
    'ready': [if (!toldReady) _ready],
    'debts': const [_debt],
    'film': const <Object>[],
  });

  @override
  Future<ToWrite> mark(
    ToWriteKind kind, {
    String? order,
    String? customer,
  }) async {
    marked.add((kind, order));
    if (kind == ToWriteKind.ready) toldReady = true;
    return todo();
  }

  @override
  Future<DailySummary> summary() async => DailySummary.fromJson(const {
    'text': 'Итоги дня 18.11 — KORKEM\nПришло: 120 000 ₸',
    'settings': {'enabled': false, 'hour': 20},
  });

  @override
  Future<DailySummary> setSummary({
    bool? enabled,
    int? hour,
    bool? morning,
  }) async => DailySummary.fromJson({
    'text': 'Итоги дня',
    'settings': {'enabled': enabled ?? false, 'hour': hour ?? 20},
  });

  @override
  Future<Map<ToWriteKind, MessageTemplate>> templates() async => {
    for (final k in ToWriteKind.values)
      k: (text: 'Здравствуйте, {имя}!', byDefault: ''),
  };

  @override
  Future<Map<ToWriteKind, MessageTemplate>> setTemplate(
    ToWriteKind kind,
    String text,
  ) async {
    saved.add((kind, text));
    return templates();
  }

  @override
  Future<
    ({
      List<({String order, int? number, double amount})> split,
      ClientCard card,
    })
  >
  pay(
    String customer, {
    required double amount,
    required String method,
    String? bank,
  }) async {
    paid.add((amount, method));
    return (
      split: [(order: 'SAL-ORD-2026-00245', number: 245, amount: amount)],
      card: await card(customer),
    );
  }

  @override
  Future<({String? phone, String text})> debtText(String customer) async => (
    phone: '+77015551234',
    text: 'Здравствуйте, Ерлан! Напоминаем об оплате по заказу № 245, 250.',
  );

  @override
  Future<ClientCard> reminded(String customer) async {
    reminders++;
    return card(customer);
  }

  @override
  Future<List<ClientEvent>> history(String customer) async => [
    for (final n in notes.reversed)
      ClientEvent(at: '2026-11-21 10:00', text: n, kind: ClientEventKind.note),
    const ClientEvent(
      at: '2026-11-20 12:00',
      text: 'Оплата: 50 000 ₸, перевод.',
      kind: ClientEventKind.money,
      order: 'SAL-ORD-2026-00245',
      number: 245,
    ),
    const ClientEvent(
      at: '2026-11-10',
      text: 'Заказ № 245 принят · Белый Матовый · 68 000 ₸',
      order: 'SAL-ORD-2026-00245',
      number: 245,
    ),
  ];

  @override
  Future<List<ClientEvent>> addNote(String customer, String text) async {
    notes.add(text);
    return history(customer);
  }

  @override
  Future<ClientCard> card(String customer) async => ClientCard.fromJson(const {
    'customer': 'CUST-1',
    'name': 'Ерлан Абенов',
    'phone': '+77015551234',
    'can': {'facades': true, 'film': false},
    'limit': 50000,
    'terms': {'discount_pct': 5},
    'orders': [
      {
        'name': 'SAL-ORD-2026-00250',
        'number': 250,
        'status': 'in_shop',
        'created_on': '2026-11-18',
        'decor': 'Белый Матовый',
        'area': 2.6,
        'stages': [
          {'key': 'cut', 'done': true},
          {'key': 'mill', 'done': false},
          {'key': 'ready', 'done': false},
        ],
        'total': 40000,
        'paid': 0,
        'debt': 40000,
        'debt_days': 3,
      },
      {
        'name': 'SAL-ORD-2026-00245',
        'number': 245,
        'status': 'ready',
        'created_on': '2026-11-10',
        'decor': 'Белый Матовый',
        'total': 68000,
        'paid': 50000,
        'debt': 18000,
        'debt_days': 11,
      },
    ],
    'payments': [
      {'date': '2026-11-14', 'order': 'SAL-ORD-2026-00245', 'amount': 50000},
    ],
    'figures': {
      'orders': 2,
      'total': 108000,
      'paid': 50000,
      'debt': 58000,
      'average': 54000,
      'first': '2026-11-10',
      'last': '2026-11-10',
    },
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _act = Reconciliation.fromJson(const {
  'since': '2026-11-01',
  'until': '2026-11-21',
  'company': 'ТОО «KORKEM»',
  'requisites': {'bin': '123456789012', 'director': 'Жупанов Е.'},
  'payer': {'name': 'ТОО «Мебель-Юг»', 'bin': '210987654321'},
  'opening': 10000,
  'debit': 108000,
  'credit': 50000,
  'closing': 68000,
  'rows': [
    {
      'date': '2026-11-10',
      'text': 'Заказ № 245 (фасады МДФ)',
      'debit': 68000,
      'credit': 0,
    },
    {
      'date': '2026-11-14',
      'text': 'Оплата по заказу № 245 · Перевод',
      'debit': 0,
      'credit': 50000,
    },
  ],
});

void main() {
  late _Fake repo;

  setUp(() => repo = _Fake());

  Future<void> pump(WidgetTester tester, Widget child) async {
    // Wide enough for the card's two columns.
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [clientCardRepositoryProvider.overrideWithValue(repo)],
        child: harness(child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('who to write to: the words are ready, and a sent one leaves', (
    tester,
  ) async {
    await pump(tester, const ToWriteScreen());

    expect(find.textContaining('Ваш заказ № 245 готов'), findsOneWidget);
    expect(find.textContaining('Напоминаем об оплате'), findsOneWidget);
    expect(find.textContaining('Итоги дня 18.11'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('tw:mark:SAL-ORD-2026-00245')),
    );
    await tester.pumpAndSettle();

    expect(repo.marked.single, (ToWriteKind.ready, 'SAL-ORD-2026-00245'));
    expect(find.textContaining('Ваш заказ № 245 готов'), findsNothing);
  });

  testWidgets('the owner writes his own words', (tester) async {
    await pump(tester, const ToWriteScreen());
    await tester.tap(find.byKey(const ValueKey('tw:templates')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tw:template:debt')),
      'Добрый день, {имя}! Остаток {долг}.',
    );
    await tester.tap(find.byKey(const ValueKey('tw:template:debt:save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single, (
      ToWriteKind.debt,
      'Добрый день, {имя}! Остаток {долг}.',
    ));
  });

  testWidgets("a customer's card: his figures, orders and payments", (
    tester,
  ) async {
    await pump(tester, const ClientCardScreen(customer: 'CUST-1'));

    expect(find.text('Ерлан Абенов'), findsOneWidget);
    expect(find.byKey(const ValueKey('figure:clc:debt')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('clc:order:SAL-ORD-2026-00245')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('clc:newOrder')), findsOneWidget);
    expect(find.byKey(const ValueKey('clc:sellFilm')), findsNothing);
    expect(find.textContaining('+7 (701) 555-12-34'), findsOneWidget);
  });

  testWidgets('his orders by where they are, with stages and how long owed', (
    tester,
  ) async {
    await pump(tester, const ClientCardScreen(customer: 'CUST-1'));
    // Ready to hand over, then in the shop — not «Принят» on every row.
    final ready = tester.getTopLeft(
      find.byKey(const ValueKey('clc:order:SAL-ORD-2026-00245')),
    );
    final work = tester.getTopLeft(
      find.byKey(const ValueKey('clc:order:SAL-ORD-2026-00250')),
    );
    expect(ready.dy < work.dy, isTrue);
    expect(
      find.byKey(const ValueKey('clc:stage:SAL-ORD-2026-00250:cut')),
      findsOneWidget,
    );
    expect(find.text('Cut ✓'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('clc:debtDays:SAL-ORD-2026-00245')),
      findsOne,
    );
    // Over his limit, and what is owed longer than a week.
    expect(find.byKey(const ValueKey('clc:limit')), findsOneWidget);
    expect(find.byKey(const ValueKey('clc:oldDebt')), findsOneWidget);
    expect(find.byKey(const ValueKey('clc:colour:Белый Матовый')), findsOne);
    // Narrowed to what owes / what is ready.
    await tester.tap(find.byKey(const ValueKey('clc:show:ready')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('clc:order:SAL-ORD-2026-00250')),
      findsNothing,
    );
  });

  testWidgets('one payment for all he owes, the oldest order first', (
    tester,
  ) async {
    await pump(tester, const ClientCardScreen(customer: 'CUST-1'));
    final pay = find.byKey(const ValueKey('clc:pay'));
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('clc:payAmount')),
      '30000',
    );
    await tester.pumpAndSettle();
    // The older order closed first, the rest on the next.
    expect(
      find.byKey(const ValueKey('clc:paySplit:SAL-ORD-2026-00245')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('clc:paySplit:SAL-ORD-2026-00250')),
      findsOne,
    );
    await tester.tap(find.byKey(const ValueKey('clc:payMethod:Наличные')));
    await tester.tap(find.byKey(const ValueKey('clc:paySave')));
    await tester.pumpAndSettle();
    expect(repo.paid, [(30000.0, 'Наличные')]);
    // More than he owes is refused before it is sent.
    await tester.tap(pay);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('clc:payAmount')),
      '90000',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('clc:paySave')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('his history on one line, narrowed, and a note added', (
    tester,
  ) async {
    await pump(tester, const ClientCardScreen(customer: 'CUST-1'));
    final tab = find.text('History');
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.textContaining('Заказ № 245 принят'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clc:hist:money')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Заказ № 245 принят'), findsNothing);
    expect(find.textContaining('Оплата: 50 000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clc:hist:all')));
    await tester.enterText(
      find.byKey(const ValueKey('clc:note')),
      'Звонить после 14:00',
    );
    await tester.tap(find.byKey(const ValueKey('clc:noteSave')));
    await tester.pumpAndSettle();
    expect(repo.notes, ['Звонить после 14:00']);
    expect(find.text('Звонить после 14:00'), findsOneWidget);
  });

  testWidgets('«Акт сверки»: a period chosen, the paper sent', (tester) async {
    final sent = <Reconciliation>[];
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          clientCardRepositoryProvider.overrideWithValue(repo),
          actSendProvider.overrideWithValue((act, l10n) async => sent.add(act)),
        ],
        child: harness(const ClientCardScreen(customer: 'CUST-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clc:act')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clc:actMake')));
    await tester.pumpAndSettle();
    expect(repo.acts, [(null, null)]);
    expect(sent.single.closing, 68000);
    await tester.tap(find.byKey(const ValueKey('clc:act')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clc:actPeriod:month')));
    await tester.tap(find.byKey(const ValueKey('clc:actMake')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(repo.acts.last.$1, mdfIso(DateTime(now.year, now.month)));
  });

  test('the act prints in every language', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final locale in ['ru', 'kk', 'en']) {
      final bytes = await buildReconciliationPdf(
        _act,
        lookupAppLocalizations(Locale(locale)),
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    }
  });
}
