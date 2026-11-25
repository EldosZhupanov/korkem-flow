// Screenshots for the design review (owner, 25.11.2026: «оцени экран от 0
// до 10 и исправь всё, что ниже 10»). Not a test: it borrows the golden
// mechanism to render each screen to a PNG — wide and light, wide and dark,
// a phone in Kazakh — for `.claude/skills/korkem-design-review`. The PNGs
// land in `test/design/shots/`, which git ignores.
//
//   flutter test test/design --tags tools --run-skipped --update-goldens
@Tags(['tools'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/client_card/presentation/client_card_screen.dart';
import 'package:korkem_flow/features/client_card/presentation/rating_screen.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/presentation/costs_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';

import '../support/widget_harness.dart';
import 'fake_costs.dart';

/// How a screen is looked at: its size, its theme, its language.
typedef _Look = ({
  String name,
  Size size,
  Brightness brightness,
  Locale locale,
});

const List<_Look> _looks = [
  (
    name: 'wide_light',
    size: Size(1400, 900),
    brightness: Brightness.light,
    locale: Locale('ru'),
  ),
  (
    name: 'wide_dark',
    size: Size(1400, 900),
    brightness: Brightness.dark,
    locale: Locale('ru'),
  ),
  (
    name: 'phone_kk',
    size: Size(390, 844),
    brightness: Brightness.light,
    locale: Locale('kk'),
  ),
];

/// The screens under review, each with the taps that open what is looked
/// at (a dialog), if any.
final Map<String, (Widget, List<String>)> _screens = {
  'client_card': (const ClientCardScreen(customer: 'CUST-1'), const []),
  'client_card_pay': (
    const ClientCardScreen(customer: 'CUST-1'),
    const ['clc:pay', 'clc:payBy:12'],
  ),
  'client_card_invoice': (
    const ClientCardScreen(customer: 'CUST-1'),
    const ['clc:invoice'],
  ),
  'customer_rating': (const CustomerRatingScreen(), const []),
  // «Расходы цеха» (25.11.2026): each tab, and the floor's own view.
  'costs_money': (CostsScreen(today: DateTime(2026, 11, 25)), const []),
  'costs_bills': (
    CostsScreen(today: DateTime(2026, 11, 25)),
    const ['cst:tab:bills'],
  ),
  'costs_bill_dialog': (
    CostsScreen(today: DateTime(2026, 11, 25)),
    const ['cst:tab:bills', 'cst:bill:CI-POWER'],
  ),
  'costs_consumables': (
    CostsScreen(today: DateTime(2026, 11, 25)),
    const ['cst:tab:consumables'],
  ),
  'costs_items': (
    CostsScreen(today: DateTime(2026, 11, 25)),
    const ['cst:tab:items'],
  ),
};

void main() {
  for (final MapEntry(key: name, value: (screen, taps)) in _screens.entries) {
    for (final look in _looks) {
      testWidgets('$name ${look.name}', (tester) async {
        tester.view
          ..physicalSize = look.size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              clientCardRepositoryProvider.overrideWithValue(_Cards()),
              filmDeptRepositoryProvider.overrideWithValue(_Requisites()),
              costsRepositoryProvider.overrideWithValue(FakeCosts()),
            ],
            child: harness(
              screen,
              brightness: look.brightness,
              locale: look.locale,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in taps) {
          final target = find.byKey(ValueKey(key));
          // Not on this layout (a phone shows the card in tabs): the shot
          // is of what there is.
          if (target.evaluate().isEmpty) break;
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/${name}_${look.name}.png'),
        );
      });
    }
  }
}

class _Requisites implements FilmDeptRepository {
  @override
  Future<Map<String, String>> requisites() async => const {
    'name': 'ТОО «KORKEM»',
    'bin': '123456789012',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A customer who looks like a real one: two orders in work, one owing for
/// weeks, an invoice paid in part, notes; and a rating of five.
class _Cards implements ClientCardRepository {
  @override
  Future<ClientCard> card(String customer) async => ClientCard.fromJson(_card);

  @override
  Future<List<ClientEvent>> history(String customer) async => const [
    ClientEvent(
      at: '2026-11-24 10:00',
      text: 'Звонить после 14:00',
      kind: ClientEventKind.note,
    ),
    ClientEvent(
      at: '2026-11-20 12:00',
      text: 'Оплата 20 000 ₸ по счёту № 12 разнесена по заказам: № 245.',
      kind: ClientEventKind.money,
    ),
  ];

  @override
  Future<CustomerRating> rating(RatingPeriod period) async =>
      CustomerRating.fromJson(const {
        'total': 1250000,
        'customers': [
          {
            'customer': 'C1',
            'name': 'ТОО «Мебель-Юг»',
            'orders': 14,
            'total': 640000,
            'paid': 640000,
            'share': 51.2,
            'class': 'A',
            'pay_days': 1.5,
            'paid_orders': 14,
            'mark': 'fast',
          },
          {
            'customer': 'C2',
            'name': 'Ерлан Абенов',
            'orders': 6,
            'total': 310000,
            'paid': 252000,
            'debt': 58000,
            'share': 24.8,
            'class': 'A',
            'pay_days': 6,
            'paid_orders': 4,
            'oldest_debt_days': 11,
            'mark': 'usual',
          },
          {
            'customer': 'C3',
            'name': 'Айгуль Сапарова',
            'orders': 4,
            'total': 180000,
            'paid': 130000,
            'debt': 50000,
            'share': 14.4,
            'class': 'B',
            'pay_days': 19,
            'paid_orders': 3,
            'oldest_debt_days': 40,
            'mark': 'slow',
          },
          {
            'customer': 'C4',
            'name': 'Бек-Мебель',
            'orders': 2,
            'total': 80000,
            'paid': 80000,
            'share': 6.4,
            'class': 'C',
          },
          {
            'customer': 'C5',
            'name': 'Нурлан Касымов',
            'orders': 1,
            'total': 40000,
            'paid': 0,
            'debt': 40000,
            'share': 3.2,
            'class': 'C',
            'oldest_debt_days': 3,
          },
        ],
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Map<String, Object> _card = {
  'customer': 'CUST-1',
  'name': 'Ерлан Абенов',
  'phone': '+77015551234',
  'organization': 'ТОО «Мебель-Юг»',
  'can': {'facades': true, 'film': false},
  'limit': 50000,
  'terms': {'discount_pct': 5},
  'payer': {'name': 'ТОО «Мебель-Юг»', 'bin': '210987654321'},
  'invoices': [
    {
      'no': '12',
      'on': '2026-11-20',
      'due_on': '2026-11-25',
      'amount': 58000,
      'payer': 'ТОО «Мебель-Юг»',
      'paid': 20000,
      'state': 'part',
    },
  ],
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
        {'key': 'mill', 'done': true},
        {'key': 'vacuum', 'done': false},
        {'key': 'ready', 'done': false},
      ],
      'total': 40000,
      'paid': 0,
      'debt': 40000,
      'debt_days': 7,
    },
    {
      'name': 'SAL-ORD-2026-00245',
      'number': 245,
      'status': 'ready',
      'created_on': '2026-11-10',
      'decor': 'Палома',
      'area': 4.1,
      'total': 68000,
      'paid': 50000,
      'debt': 18000,
      'debt_days': 15,
    },
    {
      'name': 'SAL-ORD-2026-00231',
      'number': 231,
      'status': 'handed_over',
      'created_on': '2026-10-28',
      'decor': 'Белый Матовый',
      'area': 3.3,
      'total': 52000,
      'paid': 52000,
      'debt': 0,
    },
  ],
  'payments': [
    {'date': '2026-11-20', 'order': 'SAL-ORD-2026-00245', 'amount': 20000},
    {'date': '2026-11-14', 'order': 'SAL-ORD-2026-00245', 'amount': 30000},
  ],
  'figures': {
    'orders': 3,
    'total': 160000,
    'paid': 102000,
    'debt': 58000,
    'average': 53333,
    'first': '2026-10-28',
    'last': '2026-11-18',
  },
};
