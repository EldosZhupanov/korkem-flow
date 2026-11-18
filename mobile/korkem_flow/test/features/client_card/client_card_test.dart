import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/client_card/presentation/client_card_screen.dart';
import 'package:korkem_flow/features/client_card/presentation/to_write_screen.dart';

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
  'text': 'Здравствуйте, Айгуль Сапарова! Напоминаем об оплате по заказу № 231.',
};

class _Fake implements ClientCardRepository {
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
  Future<DailySummary> setSummary({bool? enabled, int? hour}) async =>
      DailySummary.fromJson({
        'text': 'Итоги дня',
        'settings': {'enabled': enabled ?? false, 'hour': hour ?? 20},
      });

  @override
  Future<Map<ToWriteKind, MessageTemplate>> templates() async => {
    for (final k in ToWriteKind.values) k: (text: 'Здравствуйте, {имя}!', byDefault: ''),
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
  Future<ClientCard> card(String customer) async => ClientCard.fromJson(const {
    'customer': 'CUST-1',
    'name': 'Ерлан Абенов',
    'phone': '+77015551234',
    'can': {'facades': true, 'film': false},
    'orders': [
      {
        'name': 'SAL-ORD-2026-00245',
        'number': 245,
        'status': 'ready',
        'created_on': '2026-11-10',
        'total': 68000,
        'paid': 50000,
        'debt': 18000,
      },
    ],
    'payments': [
      {'date': '2026-11-14', 'order': 'SAL-ORD-2026-00245', 'amount': 50000},
    ],
    'figures': {
      'orders': 1,
      'total': 68000,
      'paid': 50000,
      'debt': 18000,
      'average': 68000,
      'first': '2026-11-10',
      'last': '2026-11-10',
    },
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Fake repo;

  setUp(() => repo = _Fake());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
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
}
