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
  final cards = <(String, Map<String, Object?>)>[];

  @override
  Future<FilmCatalog> catalog() async => FilmCatalog.fromJson(_json);

  final added = <(String, String, String?, String?)>[];
  final addedTo = <String?>[];
  final collectionCalls = <String>[];
  final dropped = <String>[];

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
  }) async {
    addedTo.add(collection);
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
  });

  testWidgets('a film is added at its maker, and its card opens', (
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
    await tester.tap(save);
    await tester.pumpAndSettle();
    // A roll is 1400 wide and 0,3 thick unless said otherwise.
    expect(repo.added.single, ('JS Group', 'Молочный', '0,3', '1400'));
    // Its card is open, to be filled in.
    expect(find.byKey(const ValueKey('filmCard:save')), findsOneWidget);
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
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

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
}
