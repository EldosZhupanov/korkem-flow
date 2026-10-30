import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/facade_jobs/data/facade_job_repository.dart';
import 'package:korkem_flow/features/facade_jobs/domain/facade_job.dart';
import 'package:korkem_flow/features/facade_jobs/presentation/facade_jobs_screen.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/crew.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements FacadeJobRepository {
  _FakeRepository(this.jobs);

  List<FacadeJob> jobs;
  final changes = <(String, FacadeJobStatus)>[];
  final crews = <List<CrewShare>?>[];

  @override
  Future<List<FacadeJob>> fetch({FacadeJobStatus? status}) async => jobs;

  @override
  Future<void> setStatus(
    String line,
    FacadeJobStatus status, {
    List<CrewShare>? crew,
  }) async {
    changes.add((line, status));
    crews.add(crew);
    jobs = [
      for (final job in jobs) job.line == line ? job.withStatus(status) : job,
    ];
  }
}

class _Colleagues extends Fake implements PieceWorkRepository {
  @override
  Future<List<Worker>> workers() async => const [
    Worker(user: 'anna@example.com', name: 'Анна'),
    Worker(user: 'boris@example.com', name: 'Борис'),
  ];

  /// A facade paid by the m², so the crew may split by m².
  @override
  Future<PieceRates> rates() async => const PieceRates(
    rates: [
      PieceRate(
        operation: PieceRate.facadeOperation,
        rateType: PieceRate.perM2,
        rate: 2000,
      ),
    ],
    canEdit: false,
  );
}

const _job = FacadeJob(
  line: 'ROW-1',
  salesOrder: 'SAL-ORD-2026-00100',
  customer: 'ТОО Уют',
  widthMm: 716,
  heightMm: 396,
  qty: 3,
  milling: 'Классика',
  finish: 'Эмаль',
  status: FacadeJobStatus.queued,
  doubleSided: true,
);

void main() {
  test('reads the server answer, unknown status falls back to queued', () {
    final job = FacadeJob.fromJson(const {
      'line': 'ROW-1',
      'sales_order': 'SO-1',
      'width_mm': 716,
      'height_mm': 396,
      'qty': 3,
      'milling': 'Классика',
      'finish': 'Эмаль',
      'status': 'Готово',
    });
    expect(job.status, FacadeJobStatus.done);
    expect(
      FacadeJobStatus.fromWire('что-то другое'),
      FacadeJobStatus.queued,
    );
  });

  test('the floor reads the decor, the edge and the colour group', () {
    final job = FacadeJob.fromJson(const {
      'line': 'ROW-3',
      'sales_order': 'SO-3',
      'status': 'В работе',
      'thickness_mm': 19,
      'decor_top': 'Графит',
      'edge_profile': 'R3',
      'color_group': 'Графит',
    });
    expect(
      (job.thicknessMm, job.decorTop, job.edgeProfile, job.colorGroup),
      (19, 'Графит', 'R3', 'Графит'),
    );
    expect(job.withStatus(FacadeJobStatus.done).decorTop, 'Графит');
  });

  test('an urgent order stays urgent when its facade moves along', () {
    final job = FacadeJob.fromJson(const {
      'line': 'ROW-2',
      'sales_order': 'SO-2',
      'status': 'В очереди',
      'urgent': true,
    });
    expect(job.urgent, isTrue);
    expect(job.withStatus(FacadeJobStatus.inWork).urgent, isTrue);
  });

  testWidgets('the floor sees sizes and moves a facade into work', (
    tester,
  ) async {
    final repo = _FakeRepository([_job]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [facadeJobRepositoryProvider.overrideWithValue(repo)],
        child: harness(const FacadeJobsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('716×396 мм'), findsOneWidget);
    expect(find.textContaining('₸'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('facadeJob:ROW-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facadeJobStatus:inWork')));
    await tester.pumpAndSettle();

    expect(repo.changes, [('ROW-1', FacadeJobStatus.inWork)]);
    expect(find.text('В работе'), findsOneWidget);
  });

  testWidgets('a facade made together splits between the crew', (
    tester,
  ) async {
    final repo = _FakeRepository([_job]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          facadeJobRepositoryProvider.overrideWithValue(repo),
          pieceWorkRepositoryProvider.overrideWithValue(_Colleagues()),
        ],
        child: harness(const FacadeJobsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('facadeJob:ROW-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facadeJobDoneTogether')));
    await tester.pumpAndSettle();

    // One person is not a crew.
    await tester.tap(find.byKey(const ValueKey('crew:anna@example.com')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crewDone')));
    await tester.pumpAndSettle();
    expect(repo.changes, isEmpty);

    await tester.tap(find.byKey(const ValueKey('crew:boris@example.com')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crewDone')));
    await tester.pumpAndSettle();

    expect(repo.changes, [('ROW-1', FacadeJobStatus.done)]);
    expect(repo.crews.single, [
      (user: 'anna@example.com', share: null, qty: null),
      (user: 'boris@example.com', share: null, qty: null),
    ]);
  });

  testWidgets('a crew can split a facade by the m² each one made', (
    tester,
  ) async {
    final repo = _FakeRepository([_job]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          facadeJobRepositoryProvider.overrideWithValue(repo),
          pieceWorkRepositoryProvider.overrideWithValue(_Colleagues()),
        ],
        child: harness(const FacadeJobsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('facadeJob:ROW-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facadeJobDoneTogether')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Who made how much, m²'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crew:anna@example.com')));
    await tester.tap(find.byKey(const ValueKey('crew:boris@example.com')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('crewShare:anna@example.com')),
      '1,5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('crewShare:boris@example.com')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey('crewDone')));
    await tester.pumpAndSettle();

    expect(repo.crews.single, [
      (user: 'anna@example.com', share: null, qty: 1.5),
      (user: 'boris@example.com', share: null, qty: 0.5),
    ]);
  });
}
