import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_relief.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_try_on.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';

import '../../support/widget_harness.dart';

/// «Надевали свои родные каталоги… чтобы клиент мог его представить»
/// (owner, 20.11.2026): the facade dressed in the shop's films and paints.
class _Paints implements PaintCatalogueRepository {
  final asked = <String?>[];

  @override
  Future<PaintCatalogue> catalogue({String? customer}) async {
    asked.add(customer);
    return PaintCatalogue.fromJson(const {
      'customer': ['ral6021'],
      'systems': [
        {'name': 'RAL Classic', 'count': 2},
      ],
      'families': ['Белые и чёрные', 'Зелёные'],
      'colours': [
        {
          'key': 'ral9010',
          'code': 'RAL 9010',
          'name': 'Чисто-белый',
          'value': 'RAL 9010 Чисто-белый',
          'system': 'RAL Classic',
          'hex': '#F1ECE1',
          'family': 'Белые и чёрные',
          'orders': 18,
        },
        {
          'key': 'ral6021',
          'code': 'RAL 6021',
          'name': 'Бледно-зелёный',
          'value': 'RAL 6021 Бледно-зелёный',
          'system': 'RAL Classic',
          'hex': '#8A9977',
          'family': 'Зелёные',
        },
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _films = FilmDecors.fromJson(const {
  'decors': [
    {
      'decor': 'D-1',
      'maker': 'Kira',
      'name': 'Дуб Сонома',
      'hex': '#C99A5E',
      'image': '/files/sonoma.jpg',
    },
    {
      'decor': 'D-2',
      'maker': 'Renolit',
      'name': 'Белый софт',
      'hex': '#F1EFE8',
    },
  ],
  'makers': [
    {'maker': 'Kira', 'count': 1},
    {'maker': 'Renolit', 'count': 1},
  ],
});

void main() {
  const v90 = CncTool(name: 'V90');
  final relief = CncRelief.of(
    width: 400,
    height: 600,
    cuts: const [
      CncCut(
        tool: 'V90',
        width: 8,
        depth: 4,
        closed: true,
        points: [
          Offset(60, 60),
          Offset(340, 60),
          Offset(340, 540),
          Offset(60, 540),
        ],
      ),
    ],
    tools: const {'V90': v90},
    nodes: 3000,
  );

  Future<_Paints> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final paints = _Paints();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filmDecorsProvider.overrideWith((ref) async => _films),
          paintCatalogueRepositoryProvider.overrideWithValue(paints),
        ],
        child: harness(
          Scaffold(
            body: CncTryOn(relief: relief, thickness: 16, customer: 'C-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return paints;
  }

  String worn(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('ctoWorn'))).data!;

  testWidgets('a film by its maker, then put aside to compare', (
    tester,
  ) async {
    await pump(tester);
    expect(worn(tester), startsWith('Bare MDF'));
    // Each maker's catalogue on its own, as the shop keeps them.
    await tester.tap(find.byKey(const ValueKey('ctoMaker:Renolit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ctoFilm:D-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ctoMaker:all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ctoFilm:D-1')));
    await tester.pumpAndSettle();
    expect(worn(tester), startsWith('Kira · Дуб Сонома'));
    // A decor with a picture can be turned across.
    expect(find.byKey(const ValueKey('ctoAcross')), findsOne);
    await tester.tap(find.byKey(const ValueKey('ctoCompare')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ctoCompared:0')), findsOne);
  });

  testWidgets('paints: his colours first, the gloss chosen, four at most', (
    tester,
  ) async {
    final paints = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('ctoPaints')));
    await tester.pumpAndSettle();
    expect(paints.asked, ['C-1']);
    final his = tester.getTopLeft(
      find.byKey(const ValueKey('ctoPaint:ral6021')),
    );
    final ours = tester.getTopLeft(
      find.byKey(const ValueKey('ctoPaint:ral9010')),
    );
    expect(his.dx < ours.dx || his.dy < ours.dy, isTrue);
    await tester.tap(find.byKey(const ValueKey('ctoPaint:ral9010')));
    await tester.tap(find.byKey(const ValueKey('ctoGloss:gloss')));
    await tester.pumpAndSettle();
    expect(worn(tester), 'RAL 9010 Чисто-белый · gloss');
    expect(find.byKey(const ValueKey('ctoAcross')), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('ctoCompare')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('ctoCompared:3')), findsOne);
    await tester.tap(find.byKey(const ValueKey('ctoCompare')));
    await tester.pumpAndSettle();
    expect(find.text('Up to four looks side by side'), findsOne);
    await tester.tap(find.byKey(const ValueKey('ctoCompareClear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ctoCompared:0')), findsNothing);
  });
}
