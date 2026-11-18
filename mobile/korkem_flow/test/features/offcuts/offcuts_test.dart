import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/offcuts/data/offcut_repository.dart';
import 'package:korkem_flow/features/offcuts/domain/offcut.dart';
import 'package:korkem_flow/features/offcuts/presentation/offcuts_screen.dart';

import '../../support/widget_harness.dart';

Map<String, Object?> _offcut(String name, int mm, int l, int w) => {
  'offcut': name,
  'thickness_mm': mm,
  'length_mm': l,
  'width_mm': w,
  'area_m2': l * w / 1e6,
  'cell': 'A-3',
  'source_order': 'SAL-ORD-2026-00231',
  'created_on': '2026-11-18',
};

class _Fake implements OffcutRepository {
  final added = <(int, int, int, String?)>[];
  final taken = <String>[];
  final used = <String>[];
  final shelf = [
    _offcut('OFC-1', 16, 1300, 600),
    _offcut('OFC-2', 18, 900, 400),
  ];

  OffcutShelf _shelf() => OffcutShelf.fromJson({
    'offcuts': shelf,
    'thicknesses': const [16, 18],
    'area_m2': 1.14,
  });

  @override
  Future<OffcutShelf> shelf() async => _shelf();

  @override
  Future<OffcutShelf> add({
    required int thicknessMm,
    required int lengthMm,
    required int widthMm,
    String? cell,
    String? note,
  }) async {
    added.add((thicknessMm, lengthMm, widthMm, cell));
    shelf.add(_offcut('OFC-3', thicknessMm, lengthMm, widthMm));
    return _shelf();
  }

  @override
  Future<OffcutShelf> use(String offcut) async {
    used.add(offcut);
    shelf.removeWhere((o) => o['offcut'] == offcut);
    return _shelf();
  }

  @override
  Future<OffcutSuggestion> suggest(String order) async =>
      OffcutSuggestion.fromJson({
        'parts': [
          if (taken.isEmpty)
            {
              'position': 2,
              'height_mm': 1000,
              'width_mm': 500,
              'offcut': shelf.first,
            },
        ],
      });

  @override
  Future<OffcutSuggestion> take(String offcut, String order) async {
    taken.add(offcut);
    return suggest(order);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Fake repo;

  setUp(() => repo = _Fake());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [offcutRepositoryProvider.overrideWithValue(repo)],
        child: harness(child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the shelf: by thickness, a piece put on, a piece taken', (
    tester,
  ) async {
    await pump(tester, const OffcutsScreen());
    expect(find.text('16 mm · 1300×600'), findsOneWidget);
    expect(find.text('18 mm · 900×400'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offcutsThickness:18')));
    await tester.pumpAndSettle();
    expect(find.text('16 mm · 1300×600'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('offcutsAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('offcutAddLength')),
      '700',
    );
    await tester.enterText(find.byKey(const ValueKey('offcutAddWidth')), '450');
    await tester.enterText(find.byKey(const ValueKey('offcutAddCell')), 'B-1');
    await tester.tap(find.byKey(const ValueKey('offcutAddSave')));
    await tester.pumpAndSettle();
    expect(repo.added.single, (18, 700, 450, 'B-1'));
    expect(find.text('18 mm · 700×450'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offcutMenu:OFC-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken into work'));
    await tester.pumpAndSettle();
    expect(repo.used, ['OFC-2']);
    expect(find.text('18 mm · 900×400'), findsNothing);
  });

  testWidgets("an order's card offers the part an offcut holds", (
    tester,
  ) async {
    await pump(tester, const OffcutSuggestionView(order: 'SAL-ORD-1'));
    expect(find.text('From offcuts: 1 part'), findsOneWidget);
    expect(
      find.text('Item 2: 1000×500 — from 1300×600, A-3'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('offcutTake:OFC-1')));
    await tester.pumpAndSettle();
    expect(repo.taken, ['OFC-1']);
    expect(find.byKey(const ValueKey('offcutSuggestion')), findsNothing);
  });
}
