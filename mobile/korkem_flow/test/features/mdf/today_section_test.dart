import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_today.dart';
import 'package:korkem_flow/features/mdf/presentation/today_section.dart';

import '../../support/widget_harness.dart';

/// The shop on 27.11.2026, as the owner saw it.
final _today = MdfToday.fromJson(const {
  'day': '2026-11-27',
  'figures': {
    'overdue': 22,
    'at_risk': 5,
    'due_soon': 7,
    'ready': 2,
    'ready_money': 420000,
    'debt': 3008880,
    'debtors': 3,
  },
  'load': [
    {
      'stage': 'cut',
      'waiting_m2': 173.4,
      'waiting_orders': 34,
      'days': 4.1,
      'jam': true,
      'nobody': false,
    },
    {
      'stage': 'mill',
      'waiting_m2': 61,
      'waiting_orders': 9,
      'days': 1.5,
      'jam': false,
      'nobody': false,
    },
  ],
  'decide': [
    {
      'kind': 'jam',
      'stage': 'cut',
      'title': 'раскрой',
      'days': 4.1,
      'waiting_m2': 173.4,
    },
    {'kind': 'at_risk', 'count': 5},
    {
      'kind': 'film',
      'count': 1,
      'films': [
        {'decor': 'KZ13 Устюрт', 'to_buy': 6.2},
      ],
    },
  ],
  'recent': [
    {
      'action': 'mdf.stage',
      'order': 'SAL-ORD-2026-00041',
      'at': '2026-11-27 00:12:00',
      'by': 'Олжас',
      'stage': 'mill',
      'done': true,
    },
  ],
});

void main() {
  testWidgets('«Сегодня»: the figures, what to decide first, the load and '
      'what was just done (27.11.2026)', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfTodayProvider.overrideWith((ref) async => _today)],
        child: harness(
          const Scaffold(body: SingleChildScrollView(child: TodaySection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('today:overdue:value')))
          .data,
      '22',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('today:atRisk:value')))
          .data,
      '5',
    );
    // The jam first, then the dates at risk, then the film.
    expect(
      find.textContaining('1. «раскрой» is the bottleneck'),
      findsOneWidget,
    );
    expect(find.textContaining('2. Will miss the date: 5'), findsOneWidget);
    expect(find.textContaining('KZ13 Устюрт 6,2 м'), findsOneWidget);
    expect(find.byKey(const ValueKey('today:load:cut')), findsOneWidget);
    expect(find.textContaining('00041'), findsOneWidget);
  });

  testWidgets('nothing to decide says so', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfTodayProvider.overrideWith(
            (ref) async => MdfToday.fromJson(const {
              'day': '2026-11-27',
              'figures': <String, Object>{},
            }),
          ),
        ],
        child: harness(
          const Scaffold(body: SingleChildScrollView(child: TodaySection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All calm'), findsOneWidget);
  });

  testWidgets('no access to the shop: the home as before', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfTodayProvider.overrideWith(
            (ref) => Future<MdfToday>.error(StateError('no access')),
          ),
        ],
        child: harness(
          const Scaffold(body: SingleChildScrollView(child: TodaySection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
