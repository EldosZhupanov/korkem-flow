import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_picker.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_swap_view.dart';

import '../../support/widget_harness.dart';

const Map<String, Object?> _white = {
  'key': 'ral9010',
  'code': 'RAL 9010',
  'name': 'Чисто-белый',
  'value': 'RAL 9010 Чисто-белый',
  'system': 'RAL Classic',
  'hex': '#F1ECE1',
  'family': 'Белые и чёрные',
  'on_list': true,
  'kg': 24,
  'enough_m2': 80,
  'area_m2': 212,
  'orders': 18,
  'top': true,
};
const Map<String, Object?> _sage = {
  'key': 'ral6021',
  'code': 'RAL 6021',
  'name': 'Бледно-зелёный',
  'value': 'RAL 6021 Бледно-зелёный',
  'system': 'RAL Classic',
  'hex': '#8A9977',
  'family': 'Зелёные',
  'trend': true,
};
const Map<String, Object?> _reseda = {
  'key': 'ral6011',
  'code': 'RAL 6011',
  'name': 'Резедово-зелёный',
  'value': 'RAL 6011 Резедово-зелёный',
  'system': 'RAL Classic',
  'hex': '#6C7C59',
  'family': 'Зелёные',
  'kg': 14,
  'delta': 4.2,
  'look': 'close',
};
const Map<String, Object?> _own = {
  'key': 'шалфейклиента',
  'code': '',
  'name': 'Шалфей клиента',
  'value': 'Шалфей клиента',
  'system': 'По образцу',
  'hex': '#9AAE8C',
  'starred': true,
};

class _Fake implements PaintCatalogueRepository {
  final taken = <String>[];
  final added = <(String, String, String?, String?)>[];
  final proposed = <(String, String, PaintSwapWay, String?)>[];
  final agreed = <(String, String)>[];

  final picked = <String>[];

  @override
  Future<String> pick(String value, {String? system}) async {
    picked.add(value);
    return value;
  }

  @override
  Future<PaintCatalogue> catalogue({String? customer}) async =>
      PaintCatalogue.fromJson(const {
    'customer': ['ral6021'],
    'systems': [
      {'name': 'RAL Classic', 'count': 3},
      {'name': 'По образцу', 'count': 1},
    ],
    'families': ['Белые и чёрные', 'Зелёные'],
    'colours': [_white, _sage, _reseda, _own],
    'can_edit': true,
  });

  @override
  Future<String> take(String value, {String? system}) async {
    taken.add(value);
    return value;
  }

  @override
  Future<void> addColour({
    required String name,
    required String system,
    String? code,
    String? hex,
    String? note,
  }) async => added.add((name, system, code, hex));

  @override
  Future<void> setColour(
    String key, {
    String? title,
    String? hex,
    bool? starred,
    bool? hidden,
    String? note,
  }) async {}

  @override
  Future<List<PaintColour>> similar({String? colour, String? hex}) async => [
    PaintColour.fromJson(_reseda),
  ];

  @override
  Future<List<PaintColour>> matchPhoto(Uint8List photo) async => [];

  @override
  Future<PaintSwapOptions> swapOptions(String order, String colour) async =>
      (hex: '#8A9977', similar: [PaintColour.fromJson(_reseda)]);

  @override
  Future<PaintSwapAsked> proposeSwap(
    String order,
    String colour,
    PaintSwapWay way, {
    String? to,
    String? waitUntil,
  }) async {
    proposed.add((order, colour, way, to));
    return (message: 'Вы согласны?', phone: null);
  }

  @override
  Future<void> agreeSwap(
    String order,
    String colour, {
    String via = 'phone',
    String? who,
  }) async => agreed.add((colour, via));

  @override
  Future<void> cancelSwap(String order, String colour) async {}
}

Future<_Fake> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1400, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Fake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paintCatalogueRepositoryProvider.overrideWithValue(repo)],
      child: harness(child),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

MdfOrder _order({List<Map<String, Object?>> swaps = const []}) =>
    MdfOrder.fromJson({
      'name': '1142',
      'status': 'in_shop',
      'customer': 'C-1',
      'customer_name': 'Ерлан',
      'phone': '+77015551234',
      'created_on': '2026-11-19',
      'delivery_date': '2026-11-26',
      'head': const <String, Object?>{},
      'lines': const [
        {
          'height_mm': 700,
          'width_mm': 400,
          'qty': 2,
          'area_m2': 0.56,
          'rate_m2': 24000,
          'amount': 13440,
          'coating': 'paint',
          'film': 'RAL 6021 Бледно-зелёный',
        },
      ],
      'pieces': 2,
      'area_m2': 0.56,
      'total': 13440,
      'paid': 0,
      'debt': 13440,
      'payments': const <Object>[],
      'stages': const <Object>[],
      'paint_swaps': swaps,
    });

void main() {
  test('a colour reads its shade, and a swap what was agreed', () {
    final c = PaintColour.fromJson(_white);
    expect(c.argb, 0xFFF1ECE1);
    expect((c.popular, c.title), (true, 'RAL 9010 Чисто-белый'));
    expect(c.matches('9010'), isTrue);
    expect(c.matches('белый'), isTrue);
    expect(c.matches('графит'), isFalse);
    expect(paintArgb('#zz'), isNull);
    final s = PaintSwap.fromJson(const {
      'key': 'ral6021',
      'from': 'RAL 6021',
      'how': 'replace',
      'to': 'RAL 6011',
      'status': 'agreed',
      'agreed_via': 'phone',
      'agreed_by': 'Ерлан',
    });
    expect((s.way, s.agreed, s.to), (PaintSwapWay.replace, true, 'RAL 6011'));
    expect(mdfPaintColours(_order()), ['RAL 6021 Бледно-зелёный']);
  });

  testWidgets('the catalogue: ours and trends first, families, a card', (
    tester,
  ) async {
    final repo = await _pump(tester, const PaintCatalogueScreen());
    expect(find.byKey(const ValueKey('pcSystem:RAL Classic')), findsOne);
    expect(find.byKey(const ValueKey('pcOurs')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcTrends')), findsOneWidget);
    // A family narrows it.
    await tester.tap(find.byKey(const ValueKey('pcFamily:Зелёные')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pcColour:ral9010')), findsNothing);
    expect(find.byKey(const ValueKey('pcColour:ral6021')), findsOneWidget);
    // A colour's card: what is on the shelf, the nearest, into use.
    await tester.tap(find.byKey(const ValueKey('pcColour:ral6021')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pcCard:ral6021')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcSimilar:ral6011')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcTake')));
    await tester.pumpAndSettle();
    expect(repo.taken, ['RAL 6021 Бледно-зелёный']);
  });

  testWidgets('the order\'s paint window: his colours first, picked as shades', (
    tester,
  ) async {
    String? got;
    MdfGloss? gloss;
    final repo = await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await showPaintPicker(
              context,
              customer: 'C-1',
              needM2: 100,
              onGloss: (g) => gloss = g,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // What this customer painted before, on top.
    expect(find.byKey(const ValueKey('ppColour:theirs:ral6021')), findsOne);
    // On the shelf, but not enough for the order: it says so.
    await tester.ensureVisible(
      find.byKey(const ValueKey('ppColour:all:ral9010')),
    );
    await tester.tap(find.byKey(const ValueKey('ppColour:all:ral9010')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not enough'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ppGloss:matt')));
    // A colour not in work yet is put there on the way.
    await tester.ensureVisible(
      find.byKey(const ValueKey('ppColour:theirs:ral6021')),
    );
    await tester.tap(find.byKey(const ValueKey('ppColour:theirs:ral6021')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ppChoose')));
    await tester.pumpAndSettle();
    expect(repo.picked, ['RAL 6021 Бледно-зелёный']);
    expect((got, gloss), ('RAL 6021 Бледно-зелёный', MdfGloss.matt));
  });

  testWidgets('a colour of our own is added with its shade', (tester) async {
    final repo = await _pump(tester, const PaintCatalogueScreen());
    await tester.tap(find.byKey(const ValueKey('pcAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pcAddName')),
      'Оливка клиента',
    );
    await tester.enterText(find.byKey(const ValueKey('pcAddHex')), '#7D765A');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pcSave')));
    await tester.pumpAndSettle();
    expect(repo.added.single, (
      'Оливка клиента',
      'По образцу',
      null,
      '#7D765A',
    ));
  });

  testWidgets('a colour no supplier has: offered, then agreed by phone', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      Scaffold(body: MdfPaintSwapView(order: _order())),
    );
    await tester.tap(find.byKey(const ValueKey('mdfSwapStart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pswDialog')), findsOneWidget);
    // No colour picked, nothing to ask.
    final ask = find.byKey(const ValueKey('pswAsk'));
    expect(tester.widget<ButtonStyleButton>(ask).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('pcSimilar:ral6011')));
    await tester.pumpAndSettle();
    await tester.tap(ask);
    await tester.pumpAndSettle();
    final (order, colour, way, to) = repo.proposed.single;
    expect(
      (order, colour, way),
      ('1142', 'RAL 6021 Бледно-зелёный', PaintSwapWay.replace),
    );
    expect(to, 'RAL 6011 Резедово-зелёный');
    expect(find.byKey(const ValueKey('pswDialog')), findsNothing);
  });

  testWidgets('asked already: the line says so, the yes taken by phone', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      Scaffold(
        body: MdfPaintSwapView(
          order: _order(
            swaps: [
              {
                'key': 'ral6021',
                'from': 'RAL 6021 Бледно-зелёный',
                'how': 'replace',
                'to': 'RAL 6011 Резедово-зелёный',
                'status': 'asked',
              },
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mdfSwap:ral6021')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pswAsked')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pswAgreePhone')));
    await tester.pumpAndSettle();
    expect(repo.agreed.single, ('RAL 6021 Бледно-зелёный', 'phone'));
  });
}
