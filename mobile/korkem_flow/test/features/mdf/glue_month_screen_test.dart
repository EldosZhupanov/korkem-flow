import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/glue_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/glue_month_screen.dart';

import '../../support/widget_harness.dart';

/// «Сверка за месяц» (owner, 17.11.2026): the weighing makes the fact; a
/// glue not weighed says so; the norm is put right to the fact in one tap.
final _month = GlueMonth.fromJson(const {
  'month': '2026-11',
  'can_edit': true,
  'total': {
    'm2': 120,
    'kg_by_norm': 12,
    'kg_counted': 3,
    'money_counted': 6300,
  },
  'glues': [
    {
      'item': 'GL-A',
      'title': 'Клей А',
      'm2': 100,
      'kg_by_norm': 10,
      'kg_counted': 3,
      'counts': 2,
      'last_count': '2026-11-15',
      'norm_g_m2': 100,
      'fact_g_m2': 130,
      'deviation_pct': 30,
      'money_by_norm': 21000,
      'money_counted': 6300,
      'cost_m2_norm': 210,
      'cost_m2_fact': 273,
    },
    {
      'item': 'GL-B',
      'title': 'Клей Б',
      'm2': 20,
      'kg_by_norm': 2,
      'kg_counted': 0,
      'counts': 0,
      'norm_g_m2': 100,
    },
  ],
});

class _Repo implements GlueStockRepository {
  final months = <String>[];
  final norms = <(String, double)>[];

  @override
  Future<GlueMonth> reconcile(String month) async {
    months.add(month);
    return month == '2026-11'
        ? _month
        : GlueMonth.fromJson({'month': month, 'glues': const <Object>[]});
  }

  @override
  Future<GlueStock> setNorm(String item, double gM2) async {
    norms.add((item, gM2));
    return GlueStock.fromJson(const {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1200, 2200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [glueStockRepositoryProvider.overrideWithValue(repo)],
      child: harness(GlueMonthScreen(today: DateTime(2026, 11, 17))),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('a month row reads the weighing', () {
    final a = _month.glues.first;
    expect((a.counted, a.factGM2, a.deviationPct), (true, 130, 30));
    expect(_month.glues.last.counted, isFalse);
    expect(_month.moneyCounted, 6300);
  });

  testWidgets('the weighed glue shows its fact; the other says it was not '
      'weighed; the next month is not yet', (tester) async {
    final repo = await _pump(tester);
    expect(repo.months, ['2026-11']);
    expect(find.byKey(const ValueKey('glueMonthTotal')), findsOne);
    expect(find.byKey(const ValueKey('glueMonthFact:GL-A')), findsOne);
    expect(find.byKey(const ValueKey('glueMonthNotCounted:GL-B')), findsOne);
    expect(find.byKey(const ValueKey('glueMonthFact:GL-B')), findsNothing);
    expect(find.byKey(const ValueKey('glueMonthFixNorm:GL-B')), findsNothing);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('glueMonthNext')),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('«Поправить норму» sets the norm to the fact', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('glueMonthFixNorm:GL-A')));
    await tester.pumpAndSettle();
    expect(repo.norms, [('GL-A', 130.0)]);
  });

  testWidgets('the month before: nothing written off', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('glueMonthPrev')));
    await tester.pumpAndSettle();
    expect(repo.months.last, '2026-10');
    expect(find.byKey(const ValueKey('glueMonthEmpty')), findsOne);
  });
}
