import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_paint_screen.dart';

import '../../support/widget_harness.dart';

Map<String, Object?> _board() => {
  'dry_hours': 24,
  'by_colour': [
    {
      'colour': 'RAL 9010',
      'area_m2': 5.2,
      'orders': [
        {
          'name': 'SO-1',
          'customer_name': 'Ерлан',
          'delivery_date': '2026-11-20',
          'area_m2': 3.2,
        },
        {
          'name': 'SO-2',
          'customer_name': 'Айгерім',
          'delivery_date': '2026-11-18',
          'area_m2': 2,
          'overdue': true,
          'client_paint': true,
          'waiting_paint': true,
        },
      ],
    },
    {
      'colour': 'RAL 7035',
      'area_m2': 1.1,
      'orders': [
        {
          'name': 'SO-3',
          'customer_name': 'Бауыржан',
          'delivery_date': '2026-11-22',
          'area_m2': 1.1,
        },
      ],
    },
  ],
  'waiting_m2': 6.3,
  'drying': [
    {
      'name': 'SO-4',
      'customer_name': 'Нұрлан',
      'dry_at': '2026-11-14 09:00:00',
      'dry': true,
      'minutes_left': 0,
      'colours': ['RAL 9010'],
      'area_m2': 2.4,
    },
    {
      'name': 'SO-5',
      'customer_name': 'Олжас',
      'dry_at': '2026-11-15 08:30:00',
      'dry': false,
      'minutes_left': 330,
      'colours': ['RAL 7035'],
      'area_m2': 1,
    },
  ],
  'coming_m2': 4,
  'coming': [
    {
      'name': 'SO-6',
      'customer_name': 'Сәуле',
      'delivery_date': '2026-11-21',
      'stage': 'mill',
      'colours': ['RAL 9010'],
      'area_m2': 4,
      'client_parts': true,
      'two_sided': true,
    },
  ],
  'popular': [
    {'colour': 'RAL 9010', 'area_m2': 40, 'orders': 12},
  ],
};

class _Paint implements MdfPaintRepository {
  final drying = <String>[];
  final undone = <String>[];
  final brought = <(String, String?)>[];

  @override
  Future<MdfPaintBoard> board() async => MdfPaintBoard.fromJson(_board());

  @override
  Future<MdfPaintBoard> startDrying(String order) async {
    drying.add(order);
    return board();
  }

  @override
  Future<MdfPaintBoard> stopDrying(String order) async {
    undone.add(order);
    return board();
  }

  @override
  Future<MdfPaintBoard> clientPaintIn(String order, {String? note}) async {
    brought.add((order, note));
    return board();
  }

  @override
  Future<MdfPaintBoard> settings({
    int? dryHours,
    double? clientPaintDiscount,
  }) => board();
}

class _Orders implements MdfOrderRepository {
  final ticked = <(String, MdfStage, bool)>[];

  @override
  Future<MdfOrder> setStage(
    String order,
    MdfStage stage, {
    required bool done,
    String? worker,
  }) async {
    ticked.add((order, stage, done));
    return MdfOrder.fromJson({'name': order, 'status': 'in_shop'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the biggest colour first, the drying counted down, the dry '
      'marked painted', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final paint = _Paint();
    final orders = _Orders();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfPaintRepositoryProvider.overrideWithValue(paint),
          mdfOrderRepositoryProvider.overrideWithValue(orders),
        ],
        child: harness(const MdfPaintScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('paintSummary'))).data,
      'To paint 6.30 м² · drying 2 · on the way 4.00 м²',
    );
    // The biggest batch is picked: its orders are listed, the other's not.
    expect(find.byKey(const ValueKey('paintOrder:SO-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('paintOrder:SO-3')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('barRow:RAL 7035')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintOrder:SO-3')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paintDry:SO-3')));
    await tester.pumpAndSettle();
    expect(paint.drying, ['SO-3']);

    // His paint is not here: «принесена» instead of «сушить».
    await tester.tap(find.byKey(const ValueKey('barRow:RAL 9010')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paintDry:SO-2')), findsNothing);
    expect(find.text('Waiting for paint'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('paintIn:SO-2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mdfClientPaintNote')),
      '2 банки × 3 л',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(paint.brought, [('SO-2', '2 банки × 3 л')]);

    // On its way: which order, where it is now, its marks.
    expect(find.byKey(const ValueKey('paintComing:SO-6')), findsOneWidget);
    expect(find.text('now: Milling'), findsOneWidget);
    expect(find.text("Customer's LMDF"), findsOneWidget);
    expect(find.text('2 sides'), findsOneWidget);

    // Still wet: how long, and a way back; dry: «краска» is ticked.
    expect(find.textContaining('5 h 30 min left'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paintUndo:SO-5')));
    await tester.pumpAndSettle();
    expect(paint.undone, ['SO-5']);
    await tester.tap(find.byKey(const ValueKey('paintDone:SO-4')));
    await tester.pumpAndSettle();
    expect(orders.ticked, [('SO-4', MdfStage.paint, true)]);
    expect(find.byKey(const ValueKey('paintPopular')), findsOneWidget);
  });
}
