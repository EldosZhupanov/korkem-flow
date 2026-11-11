import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_sources/data/film_sources_repository.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/presentation/film_sources.dart';

import '../../support/widget_harness.dart';

const _astana = <String, dynamic>{
  'supplier': 'SUP-1',
  'name': 'Adilet · Астана',
  'makers': ['Adilet'],
  'city': 'Астана',
  'contact': 'Айгуль',
  'phone': '+7 701 000 00 01',
  'note': null,
};
const _almaty = <String, dynamic>{
  'supplier': 'SUP-2',
  'name': 'Adilet · Алматы',
  'makers': ['Adilet', 'MC Group'],
  'city': 'Алматы',
  'phone': '+7 702 000 00 02',
  'lead': '5 дней',
};

class _Fake implements FilmSourcesRepository {
  final saved = <(String?, String, Map<String, String>, List<String>)>[];
  final removed = <String>[];
  final makerCards = <(String, String?, String?)>[];

  @override
  Future<FilmSources> sources() async => FilmSources.fromJson(const {
    'sources': [_almaty, _astana],
    'makers': ['Adilet', 'MC Group'],
    'can_edit': true,
  });

  @override
  Future<FilmSource> save({
    required String name,
    required Map<String, String> card,
    required List<String> makers,
    String? id,
  }) async {
    saved.add((id, name, card, makers));
    return FilmSource(id: id ?? 'SUP-9', name: name);
  }

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<FilmMaker> maker(String name) async => FilmMaker.fromJson({
    'maker': name,
    'site': 'adilet.net',
    'sources': const [_almaty, _astana],
    'can_edit': true,
  });

  @override
  Future<void> setMaker(String name, {String? site, String? note}) async =>
      makerCards.add((name, site, note));
}

Future<_Fake> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1600, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Fake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filmSourcesRepositoryProvider.overrideWithValue(repo),
      ],
      child: harness(Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('a source reads its card and says whom to ring in one line', () {
    final s = FilmSource.fromJson(_astana);
    expect((s.id, s.name), ('SUP-1', 'Adilet · Астана'));
    expect(s.makers, ['Adilet']);
    expect(s.line, 'Астана · Айгуль · +7 701 000 00 01');
    expect(s.card.containsKey('note'), isFalse);
    expect(FilmSource.fromJson(const {'supplier': 'X'}).line, '');
  });

  test('a receipt offers the maker’s own sources, or all when none', () {
    final c = FilmCatalog.fromJson(const {
      'suppliers': [
        {'supplier': 'SUP-1', 'name': 'Adilet · Астана'},
        {'supplier': 'SUP-2', 'name': 'Adilet · Алматы'},
        {'supplier': 'SUP-3', 'name': 'Kira · Астана'},
      ],
      'sources_by_maker': {
        'Adilet': ['SUP-1', 'SUP-2'],
      },
    });
    expect(
      [for (final s in c.suppliersFor('Adilet')) s.id],
      [
        'SUP-1',
        'SUP-2',
      ],
    );
    expect(c.suppliersFor('JS Group').length, 3);
  });

  testWidgets('the list shows each source with its city and telephone', (
    tester,
  ) async {
    await _pump(tester, const FilmSourcesTab());
    expect(find.text('Adilet · Астана'), findsOneWidget);
    expect(find.textContaining('+7 701 000 00 01'), findsOneWidget);
    expect(find.textContaining('Adilet, MC Group'), findsOneWidget);
  });

  testWidgets('a new source is saved with its card and its makers', (
    tester,
  ) async {
    final repo = await _pump(tester, const FilmSourcesTab());
    await tester.tap(find.byKey(const ValueKey('filmSource:add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmSrc:name')),
      'Kira · Астана',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmSrc:city')),
      'Астана',
    );
    await tester.enterText(find.byKey(const ValueKey('filmSrc:phone')), '777');
    await tester.tap(find.byKey(const ValueKey('filmSrc:maker:MC Group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSrc:save')));
    await tester.pumpAndSettle();
    final (id, name, card, makers) = repo.saved.single;
    expect((id, name), (null, 'Kira · Астана'));
    expect(makers, ['MC Group']);
    expect((card['city'], card['phone'], card['note']), ('Астана', '777', ''));
    expect(find.byKey(const ValueKey('filmSrc:save')), findsNothing);
  });

  testWidgets('a source is edited, and removed only after a yes', (
    tester,
  ) async {
    final repo = await _pump(tester, const FilmSourcesTab());
    await tester.tap(find.byKey(const ValueKey('filmSource:SUP-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filmSrc:phone')), '555');
    await tester.tap(find.byKey(const ValueKey('filmSrc:save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single.$1, 'SUP-1');
    expect(repo.saved.single.$3['phone'], '555');
    expect(repo.saved.single.$4, ['Adilet']);

    await tester.tap(find.byKey(const ValueKey('filmSource:SUP-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filmSrc:remove')));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
    await tester.tap(find.text('Remove from the list').last);
    await tester.pumpAndSettle();
    expect(repo.removed, ['SUP-1']);
  });

  testWidgets('a maker’s card lists where its film is bought', (tester) async {
    final repo = await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showFilmMakerCard(context, 'Adilet'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Adilet · Астана'), findsOneWidget);
    expect(find.text('Adilet · Алматы'), findsOneWidget);
    expect(find.textContaining('+7 702 000 00 02'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('filmMakerCard:note')),
      'завод в Ульяновске',
    );
    await tester.tap(find.byKey(const ValueKey('filmMakerCard:save')));
    await tester.pumpAndSettle();
    expect(repo.makerCards.single, (
      'Adilet',
      'adilet.net',
      'завод в Ульяновске',
    ));
  });
}
