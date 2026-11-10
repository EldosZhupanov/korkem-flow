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
  'suppliers': [
    {'supplier': 'SUP-1', 'name': 'МС-Груп', 'enabled': true},
  ],
  'can_edit': true,
};

class _Fake implements FilmCatalogRepository {
  final cards = <(String, Map<String, Object?>)>[];

  @override
  Future<FilmCatalog> catalog() async => FilmCatalog.fromJson(_json);

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
}
