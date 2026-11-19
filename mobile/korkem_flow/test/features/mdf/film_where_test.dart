import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/mdf/data/film_where_repository.dart';
import 'package:korkem_flow/features/mdf/domain/film_where.dart';
import 'package:korkem_flow/features/mdf/presentation/film_where_view.dart';

import '../../support/widget_harness.dart';

const _film = 'MC Group · Деним';

Map<String, Object?> _source(
  String supplier,
  String name, {
  required int days,
  required double price,
  required double delivery,
  required bool inTime,
  bool advised = false,
}) => {
  'supplier': supplier,
  'name': name,
  'phone': '+77010000000',
  'days': days,
  'times': 3,
  'price_known': true,
  'price_m': price,
  'delivery_m': delivery,
  'landed_m': price + delivery,
  'comes_on': '2026-11-2$days',
  'in_time': inTime,
  'advised': advised,
};

class _Fake implements FilmWhereRepository {
  _Fake({this.accepted = true});

  final bool accepted;
  final orders = <(String, double, double?, String?)>[];
  final replaced = <(String, String, String?)>[];
  bool rang = false;

  FilmWhere _where() => FilmWhere.fromJson({
    'order': 'SO-1',
    'accepted': accepted,
    'need_by': '2026-11-27',
    'urgent': false,
    'films': [
      {
        'film': _film,
        'item': 'FILM-1',
        'maker': 'MC Group',
        'short': 4.2,
        'sources': [
          _source(
            'S-ALA',
            'MC Group Алматы',
            days: 5,
            price: 1300,
            delivery: 120,
            inTime: true,
            advised: true,
          ),
          _source(
            'S-AST',
            'MC Group Астана',
            days: 2,
            price: 1450,
            delivery: 0,
            inTime: true,
          ),
        ],
        'ordered': [
          for (final o in orders)
            {
              'line': 'L-1',
              'supplier': 'MC Group Алматы',
              'metres': o.$2,
              'status': 'Open',
            },
        ],
        'nowhere': rang ? '2026-11-19' : null,
        'lookalikes': [
          {
            'decor': 'D-2',
            'maker': 'Kira Group',
            'name': 'Деним синий',
            'on_shelf': 12.0,
            'films': [
              {'item': 'FILM-2', 'label': 'Kira Group · Деним синий', 'free': 12},
            ],
          },
        ],
      },
    ],
  });

  @override
  Future<FilmWhere> where(String order) async => _where();

  @override
  Future<FilmWhere> order({
    required String order,
    required String item,
    required String supplier,
    required double metres,
    double? priceM,
    String? comesOn,
    String? saidBy,
  }) async {
    orders.add((supplier, metres, priceM, saidBy));
    return _where();
  }

  @override
  Future<FilmWhere> nowhere(String order, String item) async {
    rang = true;
    return _where();
  }

  @override
  Future<FilmWhere> replace({
    required String order,
    required String from,
    required String to,
    String? reason,
  }) async {
    replaced.add((from, to, reason));
    return _where();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester, _Fake repo, {VoidCallback? on}) async {
    tester.view.physicalSize = const Size(1600, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [filmWhereRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          SingleChildScrollView(
            child: FilmWhereView(order: 'SO-1', onChanged: on),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both branches, the cheaper advised, ordered from it', (
    tester,
  ) async {
    final repo = _Fake();
    await pump(tester, repo);
    expect(find.text('No film — where to get it'), findsOneWidget);
    expect(find.text('4,2 m short'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fwAdvised:FILM-1:S-ALA')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('fwAdvised:FILM-1:S-AST')), findsNothing);
    expect(find.textContaining('5 days → comes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fwOrder:FILM-1:S-ALA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fwOrderDialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('fwPrice')), '1350');
    await tester.enterText(find.byKey(const ValueKey('fwSaid')), 'Айгерим');
    await tester.tap(find.byKey(const ValueKey('fwOrderConfirm')));
    await tester.pumpAndSettle();
    expect(repo.orders.single, ('S-ALA', 5.0, 1350.0, 'Айгерим'));
    expect(find.textContaining('Ordered 5 m'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fwNowhere:FILM-1')));
    await tester.pumpAndSettle();
    expect(repo.rang, isTrue);
    expect(find.textContaining('Nowhere — rang everyone'), findsOneWidget);
  });

  testWidgets('a look-alike the customer agreed to replaces the film', (
    tester,
  ) async {
    final repo = _Fake();
    var changed = 0;
    await pump(tester, repo, on: () => changed++);
    expect(find.text('12 m on our shelf'), findsNothing); // in the subtitle
    expect(find.textContaining('12 m on our shelf'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fwReplace:FILM-1:D-2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('fwReplaceReason')),
      'клиент согласен',
    );
    await tester.tap(find.text('Replace').last);
    await tester.pumpAndSettle();
    expect(repo.replaced.single, (
      _film,
      'Kira Group · Деним синий',
      'клиент согласен',
    ));
    expect(changed, 1);
  });

  testWidgets('a draft shows where, but orders only once accepted', (
    tester,
  ) async {
    await pump(tester, _Fake(accepted: false));
    final order = tester.widget<FilledButton>(
      find.byKey(const ValueKey('fwOrder:FILM-1:S-ALA')),
    );
    expect(order.onPressed, isNull);
    expect(
      find.text('You can order once the order is accepted.'),
      findsOneWidget,
    );
  });

  test('a code that is the name is said once', () {
    expect(filmTitle('AS 1890-SFT-W', 'AS 1890-SFT-W'), 'AS 1890-SFT-W');
    expect(filmTitle('Белый', 'W-01'), 'Белый · W-01');
    expect(filmTitle('Белый', null), 'Белый');
  });
}
