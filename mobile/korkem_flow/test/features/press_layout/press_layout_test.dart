import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_edit.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_layout_screen.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_map.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_panel.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_settings_screen.dart';

import '../../support/widget_harness.dart';

const Map<String, Object> _press = {
  'press_length_mm': 2850,
  'press_width_mm': 1210,
  'press_margin_mm': 50,
  'press_gap_mm': 60,
  'press_sections': [
    {'film_m': 1.1, 'length_mm': 850},
    {'film_m': 2.1, 'length_mm': 1850},
    {'film_m': 3.1, 'length_mm': 2850},
  ],
  'can_edit': true,
};

Map<String, dynamic> _layout({bool corrected = false}) => {
  'sales_order': 'SO-1110',
  'press': _press,
  'can_correct': true,
  'films': [
    {
      'decor': 'ZB 852-2 Авори',
      'title': '№SO-1110 Дастан Жақсылықов ZB 852-2 Авори',
      'textured': false,
      'layout_m': 3.1,
      'film_m': corrected ? 2.1 : 3.1,
      'corrected': corrected,
      'reason': corrected ? 'плотнее вручную' : null,
      'loads': [
        {
          'film_m': 3.1,
          'length_mm': 2850,
          'placed': [
            {
              'pos': 1,
              'x': 50,
              'y': 50,
              'width': 598,
              'height': 298,
              'rotated': false,
            },
          ],
        },
      ],
      'too_big': <int>[],
    },
    {
      'decor': 'AS 1804-SFT Какао нубук',
      'title': '№SO-1110 Дастан Жақсылықов AS 1804-SFT Какао нубук',
      'textured': true,
      'layout_m': 2.1,
      'film_m': 2.1,
      'loads': [
        {
          'film_m': 2.1,
          'length_mm': 1850,
          'placed': [
            {'pos': 3, 'x': 50, 'y': 50, 'width': 598, 'height': 148},
            {'pos': 4, 'x': 708, 'y': 50, 'width': 598, 'height': 283},
          ],
        },
      ],
    },
  ],
};

class _FakeRepository implements PressLayoutRepository {
  final corrections = <(String, double?, String?)>[];
  final saved = <PressSettings>[];
  final layouts = <(String, List<PressLoad>?)>[];
  final checks = <bool>[];
  bool corrected = false;

  @override
  Future<OrderPressLayout> saveLayout(
    String salesOrder,
    String decor,
    List<PressLoad>? loads, {
    Map<String, Object>? press,
    String? forced,
  }) async {
    layouts.add((decor, loads));
    forcedWith.add(forced);
    pressFor.add(press);
    return layout(salesOrder);
  }

  final pressFor = <Map<String, Object>?>[];
  final forcedWith = <String?>[];
  final tried = <PressTune>[];

  @override
  Future<PressPreview> preview(
    String salesOrder,
    FilmLayout film,
    PressTune tune,
  ) async {
    tried.add(tune);
    // A wider gap: a longer section — 3,1 m instead of 2,1.
    final longer = tune.gapMm > 60;
    return (
      film: FilmLayout(
        decor: film.decor,
        title: film.title,
        textured: film.textured,
        layoutM: longer ? film.filmM + 1 : film.filmM,
        filmM: longer ? film.filmM + 1 : film.filmM,
        loads: film.loads,
      ),
      nowM: film.filmM,
    );
  }

  @override
  Future<OrderPressLayout> approve(
    String salesOrder, {
    bool approved = true,
  }) async {
    checks.add(approved);
    return OrderPressLayout.fromJson({
      ..._layout(),
      if (approved) 'approved': {'by': 'Олжас', 'at': '2026-11-12 15:40'},
      if (approved)
        'short': [
          {'decor': 'ZB 852-2 Авори', 'item': 'F-1', 'short_m': 3.1},
        ],
    });
  }

  @override
  Future<OrderPressLayout> layout(String salesOrder) async =>
      OrderPressLayout.fromJson(custom ?? _layout(corrected: corrected));

  /// Another order's answer, when a test needs one.
  Map<String, dynamic>? custom;

  @override
  Future<OrderPressLayout> setFilmMetres(
    String salesOrder,
    String decor, {
    double? metres,
    String? reason,
  }) async {
    corrections.add((decor, metres, reason));
    corrected = metres != null;
    return layout(salesOrder);
  }

  @override
  Future<PressSettings> settings() async => PressSettings.fromJson(_press);

  @override
  Future<PressSettings> saveSettings({
    required double lengthMm,
    required double widthMm,
    required double marginMm,
    required double gapMm,
    required List<({double filmM, double lengthMm})> sections,
  }) async {
    final result = PressSettings(
      lengthMm: lengthMm,
      widthMm: widthMm,
      marginMm: marginMm,
      gapMm: gapMm,
      sections: sections,
      canEdit: true,
    );
    saved.add(result);
    return result;
  }
}

/// The film's card, as the press screen says what the roll is.
class _Films implements FilmCatalogRepository {
  final said = <(String, FilmGrain)>[];

  @override
  Future<List<String>> setGrainAtPress(String decor, FilmGrain grain) async {
    said.add((decor, grain));
    return ['F-1'];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_FakeRepository> pump(
    WidgetTester tester,
    Widget screen, {
    Map<String, dynamic>? layout,
  }) async {
    final repo = _FakeRepository()..custom = layout;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pressLayoutRepositoryProvider.overrideWithValue(repo)],
        child: harness(screen),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test("Shift: nearer than the gap is the worker's call, on another part "
      'never (26.11.2026)', () {
    final press = PressSettings.fromJson(_press);
    const a = PlacedPart(pos: 1, x: 50, y: 50, width: 500, height: 300);
    const near = PlacedPart(pos: 2, x: 580, y: 50, width: 500, height: 300);
    const on = PlacedPart(pos: 2, x: 400, y: 50, width: 500, height: 300);
    expect(pressClashes([a, near], press), {0, 1});
    expect(pressOverlaps([a, near], press), isEmpty);
    expect(pressOverlaps([a, on], press), {0, 1});
    expect(
      pressOverlaps([
        const PlacedPart(pos: 1, x: -5, y: 0, width: 100, height: 100),
      ], press),
      {0},
    );
    expect(
      PlacedPart.fromJson(const {'pos': 1, 'forced': true}).forced,
      isTrue,
    );
  });

  test('reads the server layout', () {
    final layout = OrderPressLayout.fromJson(_layout());
    expect(layout.films, hasLength(2));
    expect(layout.films.last.textured, isTrue);
    expect(layout.films.first.loads.single.placed.single.pos, 1);
    expect(layout.press.sections.map((s) => s.filmM), [1.1, 2.1, 3.1]);
  });

  testWidgets('each film says its title, whether it turns, and its metres', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, const PressLayoutScreen(salesOrder: 'SO-1110'));

    // The order's own number, not the system's long one (13.11.2026).
    expect(
      find.text('№1110 · Дастан Жақсылықов · ZB 852-2 Авори'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pressTextured:AS 1804-SFT Какао нубук')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pressTextured:ZB 852-2 Авори')),
      findsNothing,
    );
    expect(find.text('Film: 3.1 m'), findsOneWidget);
    expect(find.byType(PressMap), findsNWidgets(2));
  });

  testWidgets('a film nobody has looked at: asked once at the press', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final films = _Films();
    final layout = _layout();
    ((layout['films']! as List).first as Map)['grain'] = '';
    final repo = _FakeRepository()..custom = layout;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pressLayoutRepositoryProvider.overrideWithValue(repo),
          filmCatalogRepositoryProvider.overrideWithValue(films),
        ],
        child: harness(const PressLayoutScreen(salesOrder: 'SO-1110')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pressGrainAsk:ZB 852-2 Авори')),
      findsOneWidget,
    );
    // The textured one is known: nothing asked of it.
    expect(
      find.byKey(const ValueKey('pressGrainAsk:AS 1804-SFT Какао нубук')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('pressGrainPlain:ZB 852-2 Авори')),
    );
    await tester.pumpAndSettle();
    expect(films.said, [('ZB 852-2 Авори', FilmGrain.plain)]);
  });

  testWidgets('a position lights up on every load, the loads say how full', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, const PressLayoutScreen(salesOrder: 'SO-1110'));
    // 598×298 on 2850×1210: 5% of the table.
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('pressFill:ZB 852-2 Авори:0')),
          )
          .data,
      startsWith('5% full'),
    );
    await tester.tap(
      find.byKey(const ValueKey('pressPosition:AS 1804-SFT Какао нубук:4')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('pressPositionInfo:AS 1804-SFT Какао нубук'),
            ),
          )
          .data,
      'Position 4 · 598×283 · 1 in all · on loads 1',
    );
    final map = tester.widget<PressMap>(
      find.byKey(const ValueKey('pressMap:AS 1804-SFT Какао нубук:0')),
    );
    expect(map.highlight, 4);
    // As on a drawing: the table and the load's section over the map.
    expect(
      map.lengthLabel,
      matches(RegExp(r'^table \d+ mm · section [\d.]+ m$')),
    );
    expect(map.widthLabel, endsWith(' mm'));
    // Beside each map, what goes on that load (owner, 26.11.2026).
    expect(
      find.byKey(const ValueKey('pressOnLoad:AS 1804-SFT Какао нубук:0')),
      findsOneWidget,
    );
    expect(
      pressPositions(
        OrderPressLayout.fromJson(_layout()).films.last,
      ).map((p) => (p.pos, p.count)),
      [(3, 1), (4, 1)],
    );
  });

  testWidgets('the press panel tries a gap and keeps it for the order', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-1110'),
    );
    // Beside the map, as in Cutting: the press's own figures to start.
    expect(find.byType(PressPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('pressCompare')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('pressTune:gap')), '80');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    // Tried at once: each film laid out again; was and will be.
    expect(repo.tried.last.gapMm, 80);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pressWillBe'))).data,
      'Will be 7.2 m',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('pressTune:keepOrder')),
    );
    await tester.tap(find.byKey(const ValueKey('pressTune:keepOrder')));
    await tester.pumpAndSettle();
    // Kept for this order alone: each film, checked by the panel's gap.
    expect(repo.layouts, hasLength(2));
    expect(repo.pressFor.first!['press_gap_mm'], 80);
    expect(repo.saved, isEmpty);
  });

  testWidgets('a manager corrects the metres with a reason', (tester) async {
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-1110'),
    );
    await tester.tap(find.byKey(const ValueKey('pressCorrect:ZB 852-2 Авори')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pressCorrectMetres')),
      '2,1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pressCorrectReason')),
      'плотнее вручную',
    );
    await tester.tap(find.byKey(const ValueKey('pressCorrectSave')));
    await tester.pumpAndSettle();

    expect(repo.corrections.single.$2, 2.1);
    expect(repo.corrections.single.$3, 'плотнее вручную');
    expect(find.textContaining('плотнее вручную'), findsOneWidget);
  });

  test('a layout made by hand keeps to the table, the gap, a section', () {
    final press = PressSettings.fromJson(_press);
    const a = PlacedPart(pos: 1, x: 50, y: 50, width: 598, height: 298);
    const b = PlacedPart(pos: 2, x: 700, y: 50, width: 598, height: 298);
    // 52 mm apart where the press wants 60: both are wrong.
    expect(pressClashes([a, b], press), {0, 1});
    // Let go near the line, the part jumps to exactly the gap.
    final snapped = pressSnapped(b, [a], press);
    expect((snapped.x, snapped.y), (708, 50));
    expect(pressClashes([a, snapped], press), isEmpty);
    // Off the table's edge is wrong too, and is pulled back on it.
    final off = pressMoved(a, 50, 1000);
    expect(pressClashes([off], press), {0});
    expect(pressSnapped(off, const [], press).y, 1210 - 50 - 298);
    // Turned, the sides swap.
    final turned = pressTurned(a);
    expect((turned.width, turned.height, turned.rotated), (298, 598, true));
    // The section is the shortest that holds the load, or a longer one named.
    expect(pressSection([a], press)?.filmM, 1.1);
    expect(pressSection([a, snapped], press)?.filmM, 2.1);
    expect(pressSection([a], press, asked: 2850)?.filmM, 3.1);
    expect(pressSection([pressMoved(a, 2400, 50)], press), isNull);
    // A part moved to another load takes the first free place.
    final placed = pressFreeSpot(b, [a], press);
    expect(pressClashes([a, placed], press), isEmpty);
    expect(pressLongest(press), 2850);
  });

  testWidgets('a part is turned by hand and the layout is kept', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-1110'),
    );
    await tester.tap(find.byKey(const ValueKey('pressEdit:ZB 852-2 Авори')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pressEdit:turn')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pressEdit:part:0:0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pressEdit:turn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pressEdit:save')));
    await tester.pumpAndSettle();

    final (decor, loads) = repo.layouts.single;
    expect(decor, 'ZB 852-2 Авори');
    final part = loads!.single.placed.single;
    expect((part.width, part.height, part.rotated), (298, 598, true));
    expect(loads.single.lengthMm, 850);
    expect(find.byKey(const ValueKey('pressEdit:save')), findsNothing);
  });

  testWidgets('order №38: the same loads once ×2, what a load costs, and '
      'the narrower gap that saves the third (26.11.2026)', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, Object> load(double m, int length, List<List<int>> parts) => {
      'film_m': m,
      'length_mm': length,
      'placed': [
        for (final p in parts)
          {'pos': p[0], 'x': p[1], 'y': p[2], 'width': p[3], 'height': p[4]},
      ],
    };
    final same = [
      [1, 0, 0, 2000, 598],
      [2, 2060, 0, 498, 498],
      [2, 2060, 558, 498, 498],
    ];
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-38'),
      layout: {
        'sales_order': 'SO-38',
        'press': {..._press, 'press_length_mm': 2750, 'press_margin_mm': 0},
        'can_correct': true,
        'films': [
          {
            'decor': 'KZ13 Устюрт',
            'title': '№38 KZ13 Устюрт',
            'layout_m': 7.3,
            'film_m': 7.3,
            'price_m': 3000,
            'hint': {'gap_mm': 54, 'film_m': 6.2, 'saves_m': 1.1},
            'loads': [
              load(3.1, 2750, same),
              load(3.1, 2750, same),
              load(1.1, 850, [
                [2, 0, 0, 498, 498],
                [2, 0, 558, 498, 498],
              ]),
            ],
          },
        ],
      },
    );
    // Loads 1 and 2 are one map, «×2».
    expect(
      find.byKey(const ValueKey('pressLoadTimes:KZ13 Устюрт:0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pressMap:KZ13 Устюрт:1')), findsNothing);
    expect(
      find.byKey(const ValueKey('pressMap:KZ13 Устюрт:2')),
      findsOneWidget,
    );
    // What it costs: 2 × 3.1 m × 3 000 ₸.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pressCost:KZ13 Устюрт:0')))
          .data,
      contains('18,600'),
    );
    // «Чуть-чуть не влезло»: tried on the panel at once.
    await tester.tap(find.byKey(const ValueKey('pressHintTry:KZ13 Устюрт')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.tried.last.gapMm, 54);
  });

  testWidgets('the manager marks the layout checked', (tester) async {
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-1110'),
    );
    await tester.tap(find.byKey(const ValueKey('pressApprove')));
    await tester.pumpAndSettle();
    expect(repo.checks, [true]);
    // Where the missing film went — one tap away (owner, 26.11.2026).
    expect(find.byKey(const ValueKey('pressShortOpen')), findsOneWidget);
    expect(find.textContaining('ZB 852-2 Авори — 3.1'), findsOneWidget);
  });

  testWidgets('the press settings are saved as typed', (tester) async {
    final repo = await pump(tester, const PressSettingsScreen());
    await tester.enterText(find.byKey(const ValueKey('pressGap')), '40');
    await tester.ensureVisible(find.byKey(const ValueKey('pressSave')));
    await tester.tap(find.byKey(const ValueKey('pressSave')));
    await tester.pumpAndSettle();

    expect(repo.saved.single.gapMm, 40);
    expect(repo.saved.single.sections, hasLength(3));
  });
}
