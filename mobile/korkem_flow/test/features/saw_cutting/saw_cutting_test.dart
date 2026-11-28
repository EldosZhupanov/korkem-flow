import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/features/saw_cutting/data/saw_cutting_repository.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_job_screen.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_journal_screen.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_parts_table.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_print.dart';
import 'package:korkem_flow/l10n/app_localizations_en.dart';

import '../../support/widget_harness.dart';

Map<String, dynamic> _plan() => {
  'rule': 'as_is/same',
  'fences': 2,
  'waste_pct': 4.8,
  'too_big': <int>[],
  'sheets': [
    {
      'fences': 2,
      'parts': [
        {
          'n': 1,
          'k': 1,
          'x': 0,
          'y': 0,
          'width': 592,
          'height': 712,
          'rotated': false,
          'edges': [2, 2, 2, 2],
        },
        {
          'n': 1,
          'k': 2,
          'x': 0,
          'y': 716,
          'width': 592,
          'height': 712,
          'rotated': false,
          'edges': [2, 2, 2, 2],
        },
      ],
      'offcuts': [
        {'x': 596, 'y': 0, 'width': 1454, 'height': 2780},
      ],
      'waste': [
        {'x': 0, 'y': 1432, 'width': 592, 'height': 1348},
      ],
      'cuts': [
        {'kind': 'trim', 'along': true, 'set': 10, 'length': 2800},
        {'kind': 'trim', 'along': false, 'set': 10, 'length': 2070},
        {
          'kind': 'strip',
          'along': true,
          'set': 592,
          'length': 2780,
          'parts': [
            [1, 1],
            [1, 2],
          ],
        },
        {
          'kind': 'cross',
          'along': false,
          'set': 712,
          'length': 592,
          'parts': [
            [1, 1],
          ],
        },
        {
          'kind': 'cross',
          'along': false,
          'set': 712,
          'length': 592,
          'parts': [
            [1, 2],
          ],
        },
      ],
    },
  ],
};

Map<String, dynamic> _job({String status = 'Checked'}) => {
  'name': 'Р-0042',
  'status': status,
  'version': 2,
  'title': '№1110 Дастан Ж.',
  'orders': [
    {'order': 'SO-1110', 'customer': 'Дастан Ж.', 'due': '2026-12-01'},
  ],
  'due_date': '2026-12-01',
  'material_item': 'MDF-16',
  'material': 'ЛДСП 16 Белый',
  'thickness_mm': 16,
  'saw': {
    'sheet_height_mm': 2800,
    'sheet_width_mm': 2070,
    'kerf_mm': 4,
    'trim_mm': 10,
    'fence_side': 'left',
    'edge_deduct': true,
  },
  'parts': [
    {
      'n': 1,
      'height': 716,
      'width': 596,
      'qty': 2,
      'rotate': true,
      'edges': [2, 2, 2, 2],
      'name': 'Боковина',
    },
  ],
  'edges': {'2': 5.25},
  'choice': 'best',
  'choices': [
    {'key': 'best', 'sheets': 1, 'fences': 2, 'waste_pct': 4.8},
  ],
  'plan': _plan(),
  'sheets_total': 1,
  'sheets_done': 0,
  'waste_pct': 4.8,
  'fences': 2,
  'sheets': [
    {'sheet_no': 1, 'status': 'Waiting', 'offcuts': <Object>[]},
  ],
  'made_by': 'Айгерим',
  'can_make': true,
  'history': [
    {
      'action': 'job_saved',
      'at': '2026-11-28 08:30',
      'who': 'Айгерим',
      'version': 2,
    },
  ],
};

class _FakeRepository implements SawCuttingRepository {
  final calculated = <List<SawPart>>[];
  final marked = <(int, bool)>[];

  @override
  Future<SawJournal> journal(JournalQuery query) async => SawJournal.fromJson({
    'jobs': [
      if (query.filter != JournalFilter.done)
        {
          'name': 'Р-0042',
          'status': 'Cutting',
          'title': '№1110 Дастан Ж.',
          'orders': <Object>[],
          'due_date': null,
          'material': 'ЛДСП 16 Белый',
          'sheets_total': 3,
          'sheets_done': 1,
          'waste_pct': 7,
          'sawn_by': ['Ерлан'],
        },
    ],
    'together': [
      {
        'jobs': ['Р-0044', 'Р-0045'],
        'material': 'ЛДСП 16 Белый',
        'apart': 5,
        'together': 4,
      },
    ],
    'materials': [
      {'item': 'MDF-16', 'name': 'ЛДСП 16 Белый', 'thickness_mm': 16},
    ],
    'can_make': true,
  });

  @override
  Future<SawCalculation> calculate(
    String materialItem,
    List<SawPart> parts,
  ) async {
    calculated.add(parts);
    return SawCalculation.fromJson({
      'sheet': {'height_mm': 2800, 'width_mm': 2070},
      'settings': {'trim_mm': 10, 'fence_side': 'right'},
      'edges': <String, Object>{},
      'choices': [
        {'key': 'best', 'sheets': 1, 'fences': 2, 'waste_pct': 4.8},
        {'key': 'offcut', 'sheets': 1, 'fences': 3, 'waste_pct': 9},
      ],
      'plans': {'best': _plan(), 'offcut': _plan()},
    });
  }

  @override
  Future<CuttingJob> job(String name) async => CuttingJob.fromJson(_job());

  @override
  Future<CuttingJob> sheetDone(
    String name,
    int sheet, {
    bool done = true,
    String? sawnBy,
    String? defects,
  }) async {
    marked.add((sheet, done));
    return CuttingJob.fromJson(_job(status: 'Done'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l10n = AppLocalizationsEn();
  final mm = NumberFormat('0.#', 'en');

  test('a job reads as the server sends it', () {
    final job = CuttingJob.fromJson(_job());
    expect(job.status, JobStatus.checked);
    expect(job.editable, isTrue);
    expect(job.orders.single.number, '№1110');
    expect(job.plan.sheets.single.parts, hasLength(2));
    expect(job.plan.sheets.single.cuts[2].kind, SawCutKind.strip);
    expect(job.part(1)?.name, 'Боковина');
    expect(job.saw.fence, FenceSide.left);
  });

  test('the cut list says the fence stays when it does', () {
    final cuts = CuttingJob.fromJson(_job()).plan.sheets.single.cuts;
    expect(sawSameFence(cuts, 3), isFalse);
    expect(sawSameFence(cuts, 4), isTrue);
    expect(sawCutText(l10n, cuts[2], mm), 'Strip · fence 592 · parts 1');
    expect(sawSheetQr('Р-0042', 1), 'SAW:Р-0042:1');
  });

  test('band metres by thickness, as the server counts them', () {
    final metres = sawEdgeMetres(const [
      SawPart(height: 766, width: 446, qty: 3, edges: [0, 2, 0.4, 0.4]),
    ]);
    expect(metres[2], closeTo(1.338, 1e-9));
    expect(metres[0.4], closeTo(4.596, 1e-9));
    expect(
      sawEdgesText(l10n, const [0, 2, 0.4, 0.4], mm),
      'bottom 2, left 0.4, right 0.4',
    );
  });

  testWidgets('a tap on a side changes its band: none, 0.4, 2, none', (
    tester,
  ) async {
    var edges = const <double>[0, 0, 0, 0];
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (context, setState) => SawEdgeCell(
            edges: edges,
            onChanged: (v) => setState(() => edges = v),
          ),
        ),
      ),
    );
    final cell = find.byType(SawEdgeCell);
    final topLeft = tester.getTopLeft(cell);
    final top = topLeft + Offset(SawEdgeCell.size.width / 2, 1);
    for (final expected in [0.4, 2.0, 0.0]) {
      await tester.tapAt(top);
      await tester.pump();
      expect(edges.first, expected);
    }
    expect(edges.skip(1), everyElement(0));
  });

  testWidgets('the journal: what to saw, by whom, and what to merge', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sawCuttingRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: harness(const SawJournalScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sawJob:Р-0042')), findsOneWidget);
    expect(find.textContaining('Ерлан'), findsOneWidget);
    expect(find.textContaining('1 of 3 sheets'), findsOneWidget);
    expect(find.byKey(const ValueKey('sawMerge')), findsOneWidget);
    expect(find.textContaining('4 sheets instead of 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sawFilter:done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sawJob:Р-0042')), findsNothing);
  });

  testWidgets('numbers first: Enter in the quantity opens the next row, '
      'and the layout is calculated', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sawCuttingRepositoryProvider.overrideWithValue(repo)],
        child: harness(const SawJobScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('sawH:0')), '716');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('sawW:0')), '596');
    await tester.enterText(find.byKey(const ValueKey('sawQ:0')), '2');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sawH:1')), findsOneWidget);
    final next = tester.widget<TextField>(find.byKey(const ValueKey('sawH:1')));
    expect(next.focusNode?.hasFocus, isTrue);

    // A band on the first part's top.
    final cell = find.byKey(const ValueKey('sawEdge:0'));
    await tester.tapAt(
      tester.getTopLeft(cell) + Offset(SawEdgeCell.size.width / 2, 1),
    );
    await tester.pump();
    expect(find.textContaining('edge 0.4 mm: 1.2 m'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sawCalculate')));
    await tester.pumpAndSettle();
    expect(repo.calculated.single.single.height, 716);
    expect(repo.calculated.single.single.qty, 2);
    expect(find.byKey(const ValueKey('sawChoice:best')), findsOneWidget);
    expect(find.byKey(const ValueKey('sawChoice:offcut')), findsOneWidget);
    expect(find.byKey(const ValueKey('sawSheet:1')), findsOneWidget);
    expect(find.textContaining('Offcut 2780 × 1454 → stock'), findsOneWidget);
  });

  testWidgets('a checked job: its sheet is marked sawn from the office', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sawCuttingRepositoryProvider.overrideWithValue(repo)],
        child: harness(const SawJobScreen(name: 'Р-0042')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready to cut'), findsOneWidget);
    expect(find.textContaining('Saved · version 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sawMark:1')));
    await tester.pumpAndSettle();
    expect(find.text('The cutter on the post'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sawMarkConfirm')));
    await tester.pumpAndSettle();
    expect(repo.marked, [(1, true)]);
  });
}
