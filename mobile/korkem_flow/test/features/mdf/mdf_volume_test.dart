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
  });
}
