import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/cnc_patterns/data/cnc_patterns_repository.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_order_sheet.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_patterns_screen.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

import '../../support/widget_harness.dart';

/// «Узоры ЧПУ (β)» (owner, 18.11.2026): a sandbox the owner turns on; a
/// pattern drawn before it is saved; an order's programs saved into a folder.
const Map<String, dynamic> _on = {
  'enabled': true,
  'visible': true,
  'can_manage': true,
  'users': <String>[],
  'people': [
    {'user': 'cutter@example.com', 'name': 'Cutter'},
  ],
  'tools': [
    {
      'name': 'V90',
      'kind': 'v',
      'diameter': 12,
      'angle': 90,
      'feed': 3000,
      'plunge': 1000,
      'rpm': 18000,
      'pass_depth': 3,
    },
  ],
  'patterns': [
    {
      'name': 'Классика',
      'milling': 'Классика',
      'min_w': 250,
      'min_h': 250,
      'example': true,
      'elements': [
        {
          'kind': 'frame',
          'tool': 'V90',
          'depth': 4,
          'offset': 60,
          'corner': 'cove',
          'radius': 15,
        },
      ],
    },
  ],
  'machine': {'ext': 'nc'},
  'millings': ['Классика', 'Модерн'],
};

const Map<String, dynamic> _preview = {
  'pattern': 'Классика',
  'example': true,
  'warnings': <String>[],
  'paths': [
    {
      'tool': 'V90',
      'width': 8,
      'closed': true,
      'points': [
        [60, 60],
        [440, 60],
        [440, 640],
        [60, 640],
        [60, 60],
      ],
    },
  ],
  'files': [
    {
      'tool': 'V90',
      'text': 'G21 G90 G17\nM30\n',
      'stats': {'cut_m': 3.86, 'passes': 2, 'minutes': 1.3},
    },
  ],
  'minutes': 1.3,
  'ext': 'nc',
};

class _Repo implements CncPatternsRepository {
  _Repo(this.json);

  Map<String, dynamic> json;
  final enabled = <bool>[];
  final previews = <(String, double, double)>[];
  final ordersAsked = <String>[];
  final artcamAdded = <List<int>>[];

  @override
  Future<CncStatus> status() async => CncStatus.fromJson(json);

  @override
  Future<List<ArtcamTool>> artcamPreview(Uint8List file) async => [
    for (final t in const [
      {
        'index': 0,
        'group': 'Metric Tools / Wood or Plastic',
        'name': 'End Mill 6 Один заход',
        'kind': 'flat',
        'diameter': 6,
        'feed': 4560,
        'rpm': 15000,
        'pass_depth': 17,
        'card': {'kind': 'flat'},
      },
      {
        'index': 1,
        'group': 'Metric Tools / Wood or Plastic',
        'name': 'Ogee 6 mm',
        'why': 'фасонная фреза — узоры её пока не режут',
      },
      {
        'index': 2,
        'group': 'Metric Tools / Steel',
        'name': 'End Mill 3 mm',
        'kind': 'flat',
        'diameter': 3,
        'card': {'kind': 'flat'},
      },
    ])
      ArtcamTool.fromJson(t),
  ];

  @override
  Future<CncStatus> artcamAdd(Uint8List file, List<int> picked) async {
    artcamAdded.add(picked);
    return CncStatus.fromJson(json);
  }

  @override
  Future<CncStatus> setEnabled({
    required bool enabled,
    List<String>? users,
  }) async {
    this.enabled.add(enabled);
    json = enabled ? _on : {...json, 'enabled': false, 'visible': false};
    return CncStatus.fromJson(json);
  }

  @override
  Future<CncPreview> preview(
    CncPattern pattern, {
    required double width,
    required double height,
  }) async {
    previews.add((pattern.name, width, height));
    return CncPreview.fromJson(_preview);
  }

  @override
  Future<CncOrderPlan> forOrder(String order) async =>
      CncOrderPlan.fromJson(const {
        'order': 'SO-1',
        'minutes': 5.2,
        'lines': [
          {
            'line': 'L1',
            'no': 1,
            'height': 718,
            'width': 500,
            'qty': 4,
            'milling': 'Классика',
            'pattern': 'Классика',
            'minutes': 1.3,
          },
          {
            'line': 'L2',
            'no': 2,
            'height': 150,
            'width': 400,
            'qty': 1,
            'milling': 'Классика',
            'pattern': 'Классика',
            'error': '«Классика» не помещается',
          },
        ],
      });

  @override
  Future<List<CncFile>> orderFiles(String order, {String? line}) async {
    ordersAsked.add('$order:${line ?? '*'}');
    return [
      CncFile.fromJson(const {
        'name': 'SO-1-01-718x500-Классика.nc',
        'text': 'G21\nM30\n',
        'qty': 4,
      }),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TdbPicker extends FilmFilePicker {
  _TdbPicker();

  @override
  Future<List<PickedFile>> pick({
    required List<String> extensions,
    bool many = false,
  }) async => [
    (name: 'tools.tdb', bytes: Uint8List.fromList(const [1, 2])),
  ];
}

class _Saver extends CncFileSaver {
  _Saver();

  final saved = <String, Map<String, String>>{};

  @override
  Future<String> save(String folder, Map<String, String> files) async {
    saved[folder] = files;
    return '/downloads/KORKEM ЧПУ/$folder';
  }

  @override
  Future<void> open(String path) async {}
}

Future<(_Repo, _Saver)> _pump(
  WidgetTester tester,
  Map<String, dynamic> json, {
  Widget child = const CncPatternsScreen(),
  FilmFilePicker? picker,
}) async {
  tester.view
    ..physicalSize = const Size(1400, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo(json);
  final saver = _Saver();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        cncPatternsRepositoryProvider.overrideWithValue(repo),
        cncFileSaverProvider.overrideWithValue(saver),
        if (picker != null) filmFilePickerProvider.overrideWithValue(picker),
      ],
      child: harness(child),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, saver);
}

void main() {
  test('the order card says whether CNC patterns are on for this user', () {
    expect(MdfOrder.fromJson(const {'name': 'SO-1', 'cnc': true}).cnc, true);
    expect(MdfOrder.fromJson(const {'name': 'SO-1'}).cnc, false);
  });

  test('an element sends only what its kind has', () {
    const frame = CncElement(
      kind: CncElementKind.frame,
      tool: 'V90',
      offset: 50,
    );
    expect(frame.toJson(), {
      'kind': 'frame',
      'tool': 'V90',
      'depth': 3.0,
      'offset': 50.0,
      'corner': 'square',
      'radius': 0,
    });
    final grooves = frame.copyWith(kind: CncElementKind.grooves, step: 40);
    expect(grooves.toJson()['direction'], 'vertical');
    expect(grooves.toJson().containsKey('offset'), isFalse);
  });

  testWidgets('off: the owner turns it on, in this base', (tester) async {
    final (repo, _) = await _pump(tester, const {
      'enabled': false,
      'visible': false,
      'can_manage': true,
    });
    expect(find.byKey(const ValueKey('cncOff')), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncEnable')));
    await tester.pumpAndSettle();
    expect(repo.enabled, [true]);
    expect(find.byKey(const ValueKey('cncBeta')), findsOne);
    expect(find.byKey(const ValueKey('cncPattern:Классика')), findsOne);
  });

  testWidgets("ArtCAM's tools: the wood ones ticked, a profile tool not", (
    tester,
  ) async {
    final (repo, _) = await _pump(
      tester,
      _on,
      picker: _TdbPicker(),
    );
    await tester.tap(find.text('Cutters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cncToolArtcam')));
    await tester.pumpAndSettle();
    expect(find.text('Ogee 6 mm'), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncArtcamAdd')));
    await tester.pumpAndSettle();
    expect(repo.artcamAdded, [
      [0],
    ]);
  });

  testWidgets('off, and not the owner: no switch to press', (tester) async {
    await _pump(tester, const {
      'enabled': false,
      'visible': false,
      'can_manage': false,
    });
    expect(find.byKey(const ValueKey('cncOff')), findsOne);
    expect(find.byKey(const ValueKey('cncEnable')), findsNothing);
  });

  testWidgets('a pattern is drawn on a facade and its program saved', (
    tester,
  ) async {
    final (repo, saver) = await _pump(tester, _on);
    await tester.tap(find.byKey(const ValueKey('cncPattern:Классика')));
    await tester.pumpAndSettle();
    expect(repo.previews, [('Классика', 500.0, 700.0)]);
    expect(find.byKey(const ValueKey('cncFacade')), findsOne);
    expect(find.byKey(const ValueKey('cncPreviewStats')), findsOne);
    // A new size is drawn again, after a pause in the typing.
    await tester.enterText(find.byKey(const ValueKey('cncTryW')), '400');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.previews.last, ('Классика', 400.0, 700.0));
    await tester.tap(find.byKey(const ValueKey('cncDownload')));
    await tester.pumpAndSettle();
    expect(saver.saved.values.single.keys, ['Классика-700x400.nc']);
  });

  testWidgets('an order: what fits is saved, what does not says why', (
    tester,
  ) async {
    final (repo, saver) = await _pump(
      tester,
      _on,
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showCncOrderSheet(context, 'SO-1'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cncLineSave:1')), findsOne);
    expect(find.byKey(const ValueKey('cncLineSave:2')), findsNothing);
    expect(find.text('«Классика» не помещается'), findsOne);
    await tester.tap(find.byKey(const ValueKey('cncOrderSaveAll')));
    await tester.pumpAndSettle();
    expect(repo.ordersAsked, ['SO-1:*']);
    expect(saver.saved['SO-1']!.keys, ['SO-1-01-718x500-Классика.nc']);
  });
}
