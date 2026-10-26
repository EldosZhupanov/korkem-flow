import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/facade_jobs/data/facade_job_repository.dart';
import 'package:korkem_flow/features/facade_jobs/domain/facade_job.dart';
import 'package:korkem_flow/features/facade_jobs/presentation/facade_jobs_screen.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements FacadeJobRepository {
  _FakeRepository(this.jobs);

  List<FacadeJob> jobs;
  final changes = <(String, FacadeJobStatus)>[];

  @override
  Future<List<FacadeJob>> fetch({FacadeJobStatus? status}) async => jobs;

  @override
  Future<void> setStatus(String line, FacadeJobStatus status) async {
    changes.add((line, status));
    jobs = [
      for (final job in jobs) job.line == line ? job.withStatus(status) : job,
    ];
  }
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
}
