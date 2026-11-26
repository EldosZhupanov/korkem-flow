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
                onPressed: () => pickMdfCrew(
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

  testWidgets('several on a stage: equal, or by hand with the rest to the '
      'last', (tester) async {
    // Owner, 26.11.2026: «2 или 3 вакуумщика делают вместе, и система делит».
    tester.view
      ..physicalSize = const Size(1200, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MdfCrewPick? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mdfWorkersProvider.overrideWith(
            (ref) async => const [
              MdfWorker(employee: 'E1', name: 'Ералы'),
              MdfWorker(employee: 'E2', name: 'Тима'),
              MdfWorker(employee: 'E3', name: 'Шамиль'),
            ],
          ),
          mdfStagePeopleProvider.overrideWith(
            (ref, key) async => const <MdfWorker>[],
          ),
        ],
        child: harness(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await pickMdfCrew(
                  context,
                  'SO-1 · Вакуум',
                  order: 'SO-1',
                  stage: MdfStage.vacuum,
                  areaM2: 10,
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
    for (final e in ['E1', 'E2', 'E3']) {
      await tester.tap(find.byKey(ValueKey('worker:$e')));
      await tester.pump();
    }
    // Equal at first: 10 m² by three.
    expect(find.byKey(const ValueKey('crewEach')), findsOneWidget);
    expect(find.textContaining('3.33'), findsOneWidget);
    await tester.tap(find.text('By hand'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('crewPart:E1')), '5');
    await tester.enterText(find.byKey(const ValueKey('crewPart:E2')), '3');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('crewRest'))).data,
      '2 м²',
    );
    // More than there is: «Готово» is off.
    await tester.enterText(find.byKey(const ValueKey('crewPart:E2')), '6');
    await tester.pump();
    expect(find.byKey(const ValueKey('crewError')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('crewDone')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const ValueKey('crewPart:E2')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('crewDone')));
    await tester.pumpAndSettle();
    expect(picked!.crew!.map((m) => (m.employee, m.share)), [
      ('E1', 50.0),
      ('E2', 30.0),
      ('E3', 20.0),
    ]);
  });
}
