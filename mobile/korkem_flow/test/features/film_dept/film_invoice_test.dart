import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_invoice_dialog.dart';

import '../../support/widget_harness.dart';

class _Fake implements FilmDeptRepository {
  Map<String, String> kept = filmRequisitesOf(null);
  final saved = <Map<String, String>>[];

  @override
  Future<Map<String, String>> requisites() async => kept;

  @override
  Future<Map<String, String>> setRequisites(Map<String, String> values) async {
    saved.add(values);
    return kept = filmRequisitesOf(values);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Fake> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1400, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Fake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [filmDeptRepositoryProvider.overrideWithValue(repo)],
      child: harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFilmInvoice(
              context,
              const FilmSale(entry: 'STE-9', date: '2026-11-15'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('an invoice asks for the requisites once, then can be made', (
    tester,
  ) async {
    final repo = await _pump(tester);

    // Nothing kept yet: the invoice says what it needs and will not go.
    expect(find.byKey(const ValueKey('filmInvoiceNoRequisites')), findsOne);
    FilledButton make() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('filmInvoiceMake')),
    );
    expect(make().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('filmInvoiceRequisites')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('filmReq:name')),
      'ТОО «KORKEM»',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmReq:bin')),
      '123456789012',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filmReq:bank')),
      'Kaspi Bank',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('filmReqSave')));
    await tester.pumpAndSettle();

    expect(repo.saved.single['name'], 'ТОО «KORKEM»');
    expect(repo.saved.single['bin'], '123456789012');
    // Back on the invoice: whose it is, and it can be made now.
    expect(find.text('ТОО «KORKEM»'), findsOne);
    expect(find.textContaining('Kaspi Bank'), findsOne);
    expect(find.byKey(const ValueKey('filmInvoiceNoRequisites')), findsNothing);
    expect(make().onPressed, isNotNull);
  });

  test('requisites off the wire carry every key, empty where none', () {
    final r = filmRequisitesOf({'name': ' ТОО ', 'bin': 123456789012});
    expect(r.keys, filmRequisiteKeys);
    expect(r['name'], 'ТОО');
    expect(r['bin'], '123456789012');
    expect(r['iik'], '');
  });
}
