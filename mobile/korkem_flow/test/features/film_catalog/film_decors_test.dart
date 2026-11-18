import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';

import '../../support/widget_harness.dart';

/// «Каталоги поставщиков» (owner, 18.11.2026): the decors with their
/// pictures; one taken in as a film; pictures put on films by file name.
const Map<String, dynamic> _decors = {
  'can_edit': true,
  'makers': [
    {'maker': 'MC Group', 'count': 3},
  ],
  'decors': [
    {
      'decor': 'd1',
      'maker': 'MC Group',
      'name': 'сиена верде',
      'collection': 'Матовая',
      'hex': '#9DAB98',
      'films': [
        {'item': 'F1', 'label': 'MC Group · сиена верде', 'on_hand': 1.7},
      ],
    },
    {
      'decor': 'd2',
      'maker': 'MC Group',
      'name': 'сиена лен',
      'collection': 'Матовая',
    },
    {
      'decor': 'd3',
      'maker': 'MC Group',
      'name': 'дуб шведский',
      'collection': 'Древесные',
      'code': 'MC 51-1',
    },
  ],
};

const Map<String, dynamic> _catalog = {
  'films': [
    {
      'item': 'F1',
      'maker': 'MC Group',
      'colour': 'сиена верде',
      'label': 'MC Group · сиена верде',
    },
    {
      'item': 'F2',
      'maker': 'GreenWood',
      'colour': 'Альберо ноче',
      'code': 'ZB 511-2',
      'label': 'GreenWood · Альберо ноче',
    },
  ],
};

class _Decors implements FilmDecorRepository {
  final made = <(String, String?, String?)>[];
  final pictures = <(String, String)>[];

  @override
  Future<FilmDecors> decors() async => FilmDecors.fromJson(_decors);

  @override
  Future<Film> fromDecor(
    String decor, {
    String? thickness,
    String? width,
  }) async {
    made.add((decor, thickness, width));
    return const Film(item: 'F9', maker: 'MC Group', colour: 'сиена лен');
  }

  @override
  Future<Film> setFilmImage(String item, PickedFile file) async {
    pictures.add((item, file.name));
    return Film(item: item, maker: '', colour: '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements FilmCatalogRepository {
  @override
  Future<FilmCatalog> catalog() async => FilmCatalog.fromJson(_catalog);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends FilmFilePicker {
  _Picker(this.files);

  final List<String> files;

  @override
  Future<List<PickedFile>> pick({
    required List<String> extensions,
    bool many = false,
  }) async => [
    for (final f in files) (name: f, bytes: Uint8List.fromList(const [1, 2])),
  ];
}

Future<_Decors> _pump(
  WidgetTester tester, {
  List<String> files = const [],
}) async {
  tester.view
    ..physicalSize = const Size(1400, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Decors();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        filmDecorRepositoryProvider.overrideWithValue(repo),
        filmCatalogRepositoryProvider.overrideWithValue(_Catalog()),
        filmFilePickerProvider.overrideWithValue(_Picker(files)),
      ],
      child: harness(const FilmDecorsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('a picture finds its film by code, by name, by maker and name', () {
    final films = FilmCatalog.fromJson(_catalog).films;
    expect(filmByFileName(films, 'ZB_511-2.jpg')?.item, 'F2');
    expect(filmByFileName(films, 'Сиена Верде.png')?.item, 'F1');
    expect(filmByFileName(films, 'MC Group · сиена верде.jpg')?.item, 'F1');
    expect(filmByFileName(films, 'нет такой.jpg'), isNull);
  });

  testWidgets('the decors show; the one the shop has says so; a collection '
      'and a search narrow them', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('fdcDecor:сиена верде')), findsOne);
    expect(find.byKey(const ValueKey('fdcHave:сиена верде')), findsOne);
    expect(find.byKey(const ValueKey('fdcHave:сиена лен')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fdcCollection:Древесные')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fdcDecor:сиена верде')), findsNothing);
    expect(find.byKey(const ValueKey('fdcDecor:дуб шведский')), findsOne);
    await tester.tap(find.byKey(const ValueKey('fdcCollection:all')));
    await tester.enterText(find.byKey(const ValueKey('fdcSearch')), 'лен');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fdcDecor:сиена лен')), findsOne);
    expect(find.byKey(const ValueKey('fdcDecor:дуб шведский')), findsNothing);
  });

  testWidgets('a decor the shop has not is taken in as a film', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('fdcDecor:сиена лен')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fdcMake')));
    await tester.pumpAndSettle();
    expect(repo.made, [('d2', '0,3', '1400')]);
  });

  testWidgets('pictures by file name go on their films; the rest are named', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      files: ['ZB 511-2.jpg', 'сиена верде.png', 'чужая.jpg'],
    );
    await tester.tap(find.byKey(const ValueKey('fdcPictures')));
    await tester.pumpAndSettle();
    expect(repo.pictures, [('F2', 'ZB 511-2.jpg'), ('F1', 'сиена верде.png')]);
    expect(find.textContaining('чужая.jpg'), findsOne);
  });
}
