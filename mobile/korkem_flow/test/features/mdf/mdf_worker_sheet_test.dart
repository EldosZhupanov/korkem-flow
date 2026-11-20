import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_worker_sheet.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';

import '../../support/widget_harness.dart';

void main() {
  testWidgets('nobody to give a stage to: a person is added on its post', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfWorkersProvider.overrideWith((ref) async => const <MdfWorker>[]),
          mdfStagePeopleProvider.overrideWith(
            (ref, key) async => const <MdfWorker>[],
          ),
          teamPeopleProvider.overrideWith(
            (ref) async => TeamPeople.fromJson(const {
              'departments': [
                {
                  'key': 'cut',
                  'title': 'Раскрой',
                  'posts': [
                    {'key': 'cut.cutter', 'title': 'Раскройщик'},
                  ],
                },
              ],
              'people': <Object>[],
            }),
          ),
        ],
        child: harness(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickMdfWorker(
                  context,
                  'SO-1 · Раскрой',
                  order: 'SO-1',
                  stage: MdfStage.cut,
                  assigning: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody in «Команда» yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workerAdd')));
    await tester.pumpAndSettle();
    // «Команда»'s own window, on the cutter's post already.
    expect(find.byKey(const ValueKey('teamPersonName')), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('teamPost:cut.cutter')))
          .selected,
      isTrue,
    );
  });
}
