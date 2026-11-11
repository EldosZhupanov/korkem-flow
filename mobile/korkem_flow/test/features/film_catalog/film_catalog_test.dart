import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';

import '../../support/widget_harness.dart';

const _json = <String, dynamic>{
  'films': [
    {
      'item': 'MAT-1',
      'maker': 'KIRA',
      'colour': 'Белый Матовый',
      'label': 'KIRA · Белый Матовый',
      'code': 'KR-101',
      'type': 'Матовая',
      'hex': '#F4F3EE',
      'thickness_mm': 0.3,
      'width_mm': 1400,
      'on_hand': 84,
      'held': 0,
      'price_m': 3200,
    },
    {
      'item': 'MAT-2',
      'maker': 'JS Group',
      'colour': 'Белый Матовый',
      'type': 'Матовая',
      'on_hand': 0,
    },
    {
      'item': 'MAT-3',
      'maker': 'KIRA',
      'colour': 'Шалфей',
      'type': 'Софт',
      'collection': 'Wood',
      'on_hand': 0,
    },
    {
      'item': 'MAT-4',
      'maker': 'KIRA',
      'colour': 'Орех',
      'enabled': false,
    },
  ],
  'unassigned': ['Палома'],
  'makers': ['JS Group', 'KIRA'],
  'types': ['Матовая', 'Софт'],
  'collections': {
    'KIRA': ['Solid', 'Wood'],
  },
  'suppliers': [
    {'supplier': 'SUP-1', 'name': 'МС-Груп', 'enabled': true},
  ],
  'can_edit': true,
};

class _Fake implements FilmCatalogRepository {
  _Fake([this.json = _json]);

  final Map<String, dynamic> json;
  final cards = <(String, Map<String, Object?>)>[];

  @override
  Future<FilmCatalog> catalog() async => FilmCatalog.fromJson(json);

  final added = <(String, String, String?, String?)>[];
  final addedTo = <String?>[];
  final collectionCalls = <String>[];
  final dropped = <String>[];
  final addedCards = <Map<String, String>>[];
  final acts = <String>[];

  @override
  Future<void> archive(String item) async => acts.add('archive $item');

  @override
  Future<void> restore(String item) async => acts.add('restore $item');

  @override
  Future<void> delete(String item) async => acts.add('delete $item');

  @override
  Future<List<FilmChange>> changes(String item) async => const [
    FilmChange(
      when: '2026-11-11 15:40',
      who: 'Olzhas',
      what: 'розница',
      before: '3900',
      after: '4100',
    ),
  ];

  @override
  Future<void> addCollection(String maker, String name) async =>
      collectionCalls.add('add $maker $name');

  @override
  Future<void> renameCollection(
    String maker,
    String name,
    String newName,
  ) async => collectionCalls.add('rename $maker $name $newName');

  @override
  Future<void> removeCollection(String maker, String name) async =>
      collectionCalls.add('remove $maker $name');

  @override
  Future<void> dropUnassigned(String colour) async => dropped.add(colour);

  @override
  Future<Film> add({
    required String maker,
    required String colour,
    String? thickness,
    String? width,
    String? collection,
    Map<String, String> card = const {},
  }) async {
    addedTo.add(collection);
    addedCards.add(card);
    added.add((maker, colour, thickness, width));
    return Film(item: 'MAT-9', maker: maker, colour: colour);
  }

  @override
  Future<Film> setCard(String item, Map<String, Object?> card) async {
    cards.add((item, card));
    return Film.fromJson(
      (_json['films']! as List).first as Map<String, dynamic>,
    );
  }
}

void main() {
  test("each maker's films apart, by type and by search", () {
    final c = FilmCatalog.fromJson(_json);
    expect(c.tabs, ['JS Group', 'KIRA']);
    // The same colour at two makers is two films, never one list.
    expect([for (final f in c.of('KIRA')) f.item], ['MAT-1', 'MAT-3', 'MAT-4']);
    expect([for (final f in c.of('JS Group')) f.item], ['MAT-2']);
    expect([for (final f in c.of('KIRA', type: 'Софт')) f.item], ['MAT-3']);
    expect([for (final f in c.of('KIRA', search: 'kr-1')) f.item], ['MAT-1']);
    // A maker's own collections; another maker has none of them.
    expect(c.collectionsOf('KIRA'), ['Solid', 'Wood']);
    expect(c.collectionsOf('JS Group'), isEmpty);
    expect(
      [for (final f in c.of('KIRA', collection: 'Wood')) f.item],
      [
        'MAT-3',
      ],
    );
    expect(c.films.first.argb, 0xFFF4F3EE);
    expect(c.films.first.free, 84);
    expect(c.suppliers.single.name, 'МС-Груп');
  });

  testWidgets('a tab per maker; a film opens its card and saves it', (
    tester,
  ) async {
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmMaker:KIRA')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmMaker:none')), findsOneWidget);
    // The first tab is JS Group's: only its film.
    expect(find.byKey(const ValueKey('film:MAT-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('film:MAT-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('filmMaker:KIRA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('film:MAT-1')), findsOneWidget);
    expect(find.text('in stock · 84 m'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('film:MAT-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmCard:ral')), '9003');
    await tester.tap(find.byKey(const ValueKey('filmCard:save')));
    await tester.pumpAndSettle();
    expect(repo.cards.single.$1, 'MAT-1');
    expect(repo.cards.single.$2['ral'], '9003');
    expect(repo.cards.single.$2['code'], 'KR-101');
    // The name and the roll are on the card too.
    expect(repo.cards.single.$2['colour'], 'Белый Матовый');
    expect(repo.cards.single.$2['thickness'], '0,3');
  });

  testWidgets('a film card shows its history, archives and deletes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmMaker:KIRA')));
    await tester.pumpAndSettle();
    // A film in the archive is not among the films in use, but behind
    // its own chip.
    expect(find.byKey(const ValueKey('film:MAT-4')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('filmArchive:KIRA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('film:MAT-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('film:MAT-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('filmArchive:KIRA')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('film:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCard:history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('розница: 3900 → 4100'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filmCard:archive')));
    await tester.pumpAndSettle();
    expect(repo.acts, ['archive MAT-1']);

    // Delete asks first.
    await tester.tap(find.byKey(const ValueKey('film:MAT-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCard:delete')));
    await tester.pumpAndSettle();
    expect(repo.acts, ['archive MAT-1']);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.acts, ['archive MAT-1', 'delete MAT-1']);
    expect(find.byKey(const ValueKey('filmCard:save')), findsNothing);
  });

  testWidgets('a film is added with all it has, and «save and more» stays', (
    tester,
  ) async {
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmAdd:JS Group')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('filmAdd:save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('filmAdd:name')),
      'Молочный',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmAdd:code')), 'JS-1');
    await tester.enterText(
      find.byKey(const ValueKey('filmAdd:retail')),
      '3900',
    );
    await tester.tap(find.byKey(const ValueKey('filmAdd:more')));
    await tester.pumpAndSettle();
    // A roll is 1400 wide and 0,3 thick unless said otherwise.
    expect(repo.added.single, ('JS Group', 'Молочный', '0,3', '1400'));
    expect(repo.addedCards.single['code'], 'JS-1');
    expect(repo.addedCards.single['retail_m'], '3900');
    // The window stays for the next film, its name and code cleared.
    expect(find.byKey(const ValueKey('filmAdd:added')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('filmAdd:name')))
          .controller!
          .text,
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmAdd:name')),
      'Сливочный',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.added.length, 2);
    // Saved, the window closes; no card opens after it.
    expect(save, findsNothing);
    expect(find.byKey(const ValueKey('filmCard:save')), findsNothing);
  });

  testWidgets('a film for an order: the maker, then its film by name', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(_Fake())],
        child: harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showFilmPicker(context),
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    // JS Group opens first; its film has no name for an order, so none shows.
    expect(find.byKey(const ValueKey('film:MAT-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pickMaker:KIRA')));
    await tester.pumpAndSettle();
    // Only KIRA's films that are still made and named.
    expect(find.byKey(const ValueKey('film:MAT-4')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('film:MAT-1')));
    await tester.pumpAndSettle();
    expect(picked, 'KIRA · Белый Матовый');
  });

  testWidgets('a maker has its own collections: filter, add into, keep', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmMaker:KIRA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('film:MAT-1')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('filmCollectionChip:KIRA:Wood')),
    );
    await tester.pumpAndSettle();
    // Only the collection's films.
    expect(find.byKey(const ValueKey('film:MAT-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('film:MAT-1')), findsNothing);

    // A film added now goes into the open collection.
    await tester.tap(find.byKey(const ValueKey('filmAdd:KIRA')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmAdd:name')), 'Дуб');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmAdd:save')));
    await tester.pumpAndSettle();
    expect(repo.addedTo.single, 'Wood');

    // The list of collections is the owner's: add, rename, remove.
    await tester.tap(find.byKey(const ValueKey('filmCollections:KIRA')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCollection:add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmCollection:name')),
      'Soft',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCollection:ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCollection:edit:Wood')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmCollection:name')),
      'Древесные',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCollection:ok')));
    await tester.pumpAndSettle();
    expect(repo.collectionCalls, [
      'add KIRA Soft',
      'rename KIRA Wood Древесные',
    ]);
  });

  testWidgets('an old colour without a maker is taken off after a yes', (
    tester,
  ) async {
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmMaker:none')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmLooseDrop:Палома')));
    await tester.pumpAndSettle();
    expect(repo.dropped, isEmpty);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.dropped, ['Палома']);
  });

  testWidgets('a film window picks from a list it keeps itself', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FilmCatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmMaker:KIRA')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmAdd:KIRA')));
    await tester.pumpAndSettle();
    // Every list has its own button beside it.
    for (final key in [
      'filmAdd:type:edit',
      'filmAdd:collection:edit',
      'filmAdd:supplier:edit',
      'filmAdd:thickness:edit',
      'filmAdd:width:edit',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    // The collections open; one tapped there is chosen here.
    await tester.tap(find.byKey(const ValueKey('filmAdd:collection:edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmCollection:Solid')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmAdd:name')), 'Лён');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmAdd:save')));
    await tester.pumpAndSettle();
    expect(repo.addedTo.single, 'Solid');
  });

  testWidgets('one film of several thicknesses: one row, a roll each', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const json = <String, dynamic>{
      'films': [
        {
          'item': 'BD-30',
          'maker': 'Adilet',
          'colour': 'Белое дерево',
          'label': 'Adilet · Белое дерево · 0,3',
          'code': '1155-BD',
          'thickness_mm': 0.3,
          'width_mm': 1400,
          'on_hand': 40,
          'retail_m': 4200,
        },
        {
          'item': 'BD-18',
          'maker': 'Adilet',
          'colour': 'Белое дерево',
          'label': 'Adilet · Белое дерево · 0,18',
          'code': '1155-BD',
          'thickness_mm': 0.18,
          'width_mm': 1400,
          'on_hand': 0,
          'retail_m': 3500,
        },
      ],
      'makers': ['Adilet'],
      'can_edit': true,
    };
    final repo = _Fake(json);
    final c = FilmCatalog.fromJson(json);
    expect(
      [for (final v in c.variantsOf(c.films.first)) v.item],
      [
        'BD-18',
        'BD-30',
      ],
    );
    expect(FilmCatalog.grouped(c.films).length, 1);

    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () async => picked = await showFilmPicker(context),
                  child: const Text('pick'),
                ),
                TextButton(
                  onPressed: () => showFilmCard(context, c.films.first, c),
                  child: const Text('card'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // An order picks the film, then its thickness.
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    // One row, its thicknesses together.
    expect(find.textContaining('0,18 / 0,3 мм'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('film:BD-18')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pickThick:BD-30')));
    await tester.pumpAndSettle();
    expect(picked, 'Adilet · Белое дерево · 0,3');

    // The card: the film once, each thickness with its own prices.
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filmVariant:BD-18')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmVariant:BD-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('filmCard:addThickness')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('filmCard:retail:1')),
      '4300',
    );
    await tester.tap(find.byKey(const ValueKey('filmCard:save')));
    await tester.pumpAndSettle();
    // The film's own once with the thinnest; the other only its prices.
    expect([for (final c in repo.cards) c.$1], ['BD-18', 'BD-30']);
    expect(repo.cards.first.$2['code'], '1155-BD');
    expect(repo.cards.last.$2['retail_m'], '4300');
    expect(repo.cards.last.$2.containsKey('code'), isFalse);
  });

  testWidgets('a thickness is taken off a film after a yes', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const json = <String, dynamic>{
      'films': [
        {'item': 'A', 'maker': 'M', 'colour': 'Лён', 'thickness_mm': 0.3},
        {'item': 'B', 'maker': 'M', 'colour': 'Лён', 'thickness_mm': 0.25},
      ],
      'makers': ['M'],
      'can_edit': true,
    };
    final repo = _Fake(json);
    final c = FilmCatalog.fromJson(json);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filmCatalogRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showFilmCard(context, c.films.first, c),
              child: const Text('card'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmVariant:delete:B')));
    await tester.pumpAndSettle();
    expect(repo.acts, isEmpty);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.acts, ['delete B']);
    // The card stays open on the rest of the film.
    expect(find.byKey(const ValueKey('filmCard:save')), findsOneWidget);
  });
}
