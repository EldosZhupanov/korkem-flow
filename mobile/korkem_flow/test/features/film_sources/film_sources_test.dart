import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_sources/data/film_sources_repository.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/domain/film_supplier_board.dart';
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

// Astana's film sold three times Almaty's; a film of its ran low and it
// comes late. Almaty has a roll on its way and two films lying idle.
const _board = <String, dynamic>{
  'period': 'month',
  'sold_m': 40,
  'amount': 156000,
  'on_hand_m': 160,
  'coming_m': 20,
  'coming_count': 1,
  'reorder_films': 1,
  'owed': 180000,
  'owed_suppliers': 1,
  'suppliers': [
    {
      'supplier': 'SUP-1',
      'name': 'Adilet · Астана',
      'phone': '+7 701 000 00 01',
      'sold_m': 30,
      'amount': 117000,
      'share': 75,
      'on_hand_m': 120,
      'lead_days': 6,
      'promised_days': 2,
      'late_days': 4,
      // Owed for film on credit; six rolls of ten on time; 4% dearer.
      'owed': 180000,
      'on_time': 6,
      'rolls': 10,
      'price_change': 4.2,
      'reorder': [
        {'item': 'F-1', 'title': 'Adilet · Белый', 'metres': 150, 'free': 20},
      ],
    },
    {
      'supplier': 'SUP-2',
      'name': 'Adilet · Алматы',
      'phone': '+7 702 000 00 02',
      'sold_m': 10,
      'amount': 39000,
      'share': 25,
      'on_hand_m': 40,
      'coming': {'metres': 20, 'count': 1, 'due': '2026-11-14'},
      'idle': {'films': 2, 'metres': 48},
    },
  ],
};

class _Fake implements FilmSourcesRepository {
  final saved = <(String?, String, Map<String, String>, List<String>)>[];

  /// Each asking of the board: for all time, or this month.
  final boards = <bool>[];

  @override
  Future<FilmSupplierBoard> board({bool allTime = false}) async {
    boards.add(allTime);
    return FilmSupplierBoard.fromJson(_board);
  }

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

  test('the board reads whose film sold, and what to do about each', () {
    final b = FilmSupplierBoard.fromJson(_board);
    expect((b.allTime, b.soldM, b.amount, b.topM), (false, 40, 156000, 30));
    final astana = b.row('SUP-1')!;
    expect((astana.leadDays, astana.promisedDays, astana.lateDays), (6, 2, 4));
    expect(astana.reorder.single.metres, 150);
    // No WhatsApp of its own: an order is written to its telephone.
    expect(astana.writeTo, '+7 701 000 00 01');
    expect(astana.fine, isFalse);
    final almaty = b.row('SUP-2')!;
    expect(
      (almaty.coming?.metres, almaty.idleFilms, almaty.idleM),
      (
        20,
        2,
        48,
      ),
    );
    expect(b.row('SUP-9'), isNull);
    // Someone who does not see money gets metres only.
    expect(FilmSupplierBoard.fromJson(const {'sold_m': 5}).amount, isNull);
  });

  testWidgets('the board ranks the sources and says what to do', (
    tester,
  ) async {
    final repo = await _pump(tester, const FilmSourcesTab());
    String text(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(text('filmSup:sold'), '40 m');
    expect(text('filmSup:coming'), '20 m');
    expect(text('filmSup:reorder'), 'films: 1');
    // The best seller first, with a medal.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('filmSource:SUP-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('filmSource:SUP-2'))).dy,
      ),
    );
    expect(find.text('🥇'), findsOneWidget);
    expect(text('filmSup:sold:SUP-1'), '30 m');
    expect(find.text('75% of sales'), findsOneWidget);
    // Astana: a film ran low and it comes late — nothing says «all is well».
    expect(find.text('To order: 1'), findsOneWidget);
    expect(find.text('Late by 4 d on average'), findsOneWidget);
    expect(find.textContaining('brings in 6 d (promised 2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('filmSup:ok:SUP-1')), findsNothing);
    // The money side: what we owe it, how it keeps its word, its price.
    expect(text('filmSup:owed'), contains('180'));
    expect(find.byKey(const ValueKey('filmSup:owed:SUP-1')), findsOneWidget);
    expect(find.text('on time 6 of 10'), findsOneWidget);
    expect(find.text('price ▲ 4%'), findsOneWidget);
    expect(find.byKey(const ValueKey('filmSup:owed:SUP-2')), findsNothing);
    // Almaty: a roll on its way, and film lying idle.
    expect(find.text('20 m on its way · 14.11'), findsOneWidget);
    expect(find.text('Lying idle: 2 · 48 m'), findsOneWidget);
    // All time is asked for apart.
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(repo.boards, [false, true]);
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

  testWidgets('a film window picks its supplier, the maker’s own first', (
    tester,
  ) async {
    String? picked = 'none';
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showFilmSourcePicker(context, maker: 'MC Group'),
          child: const Text('pick'),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    // Almaty sells MC Group: it comes first, Astana after.
    final almaty = tester.getTopLeft(
      find.byKey(const ValueKey('filmSourcePick:SUP-2')),
    );
    final astana = tester.getTopLeft(
      find.byKey(const ValueKey('filmSourcePick:SUP-1')),
    );
    expect(almaty.dy, lessThan(astana.dy));
    expect(
      find.byKey(const ValueKey('filmSourcePick:edit:SUP-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('filmSourcePick:SUP-2')));
    await tester.pumpAndSettle();
    expect(picked, 'SUP-2');
  });
}
