import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_volume_screen.dart';

import '../../support/widget_harness.dart';

final _volume = MdfVolume.fromJson(const {
  'workers': [
    {
      'worker': 'HR-EMP-1',
      'worker_name': 'Ерлан',
      'orders': 2,
      'area_m2': 12.64,
      'stages': {'cut': 3.04, 'vacuum': 9.6},
    },
    {
      'worker': null,
      'orders': 1,
      'area_m2': 3.04,
      'stages': {'mill': 3.04},
    },
  ],
  'stages': [
    {'stage': 'cut', 'orders': 1, 'area_m2': 3.04},
    {'stage': 'mill', 'orders': 1, 'area_m2': 3.04},
    {'stage': 'vacuum', 'orders': 1, 'area_m2': 9.6},
  ],
  'unassigned_m2': 3.04,
  'days': [
    {'date': '2026-11-13', 'area_m2': 6.08},
    {'date': '2026-11-14', 'area_m2': 9.6},
  ],
  'previous_m2': 7.84,
  'queue': [
    {'stage': 'paint', 'orders': 3, 'area_m2': 12.5},
    {'stage': 'vacuum', 'orders': 1, 'area_m2': 2},
  ],
});

void main() {
  testWidgets('each worker with their m², and what nobody was named on', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfVolumeProvider.overrideWith((ref, p) async => _volume),
        ],
        child: harness(MdfVolumeScreen(today: DateTime(2026, 11, 7))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('volume:HR-EMP-1')), findsOneWidget);
    expect(find.text('Ерлан'), findsOneWidget);
    expect(find.byKey(const ValueKey('volume:-')), findsOneWidget);
    expect(find.byKey(const ValueKey('volumeUnassigned')), findsOneWidget);
    // The shop's dashboard: 15,68 m² against 7,84 before — doubled; a bar a
    // day, a tapped one says its m²; done and waiting by stage.
    expect(find.text('15.68 м²'), findsOneWidget);
    expect(find.textContaining('▲ 100%'), findsOneWidget);
    expect(find.byKey(const ValueKey('barRow:done:vacuum')), findsOneWidget);
    expect(find.byKey(const ValueKey('barRow:queue:paint')), findsOneWidget);
    final chart = find.byKey(const ValueKey('volumeChart'));
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    final box = tester.getRect(chart);
    await tester.tapAt(box.topLeft + Offset(box.width * 0.75, 40));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('volumeDay'))).data,
      '14.11.2026: 9.60 м²',
    );
  });
}
