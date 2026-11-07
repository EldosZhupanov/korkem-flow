import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';

import '../../support/widget_harness.dart';

/// Keeps the lists in memory, as the server would.
class _FakeRepository implements MdfOrderRepository {
  final Map<MdfDictKind, List<MdfDictEntry>> lists = {
    MdfDictKind.patina: [const MdfDictEntry(id: 'p1', value: 'Жоқ/Нет')],
  };
  var _next = 0;

  MdfDictionaries get _now => MdfDictionaries({
    for (final e in lists.entries) e.key: List.of(e.value),
  });

  @override
  Future<MdfDictionaries> dictionaries() async => _now;

  @override
  Future<MdfDictionaries> dictionaryAdd(MdfDictKind kind, String value) async {
    (lists[kind] ??= []).add(MdfDictEntry(id: 'n${_next++}', value: value));
    return _now;
  }

  @override
  Future<MdfDictionaries> dictionaryRename(
    MdfDictKind kind,
    String option,
    String value,
  ) async {
    final l = lists[kind]!;
    final i = l.indexWhere((e) => e.id == option);
    l[i] = MdfDictEntry(id: option, value: value);
    return _now;
  }

  @override
  Future<MdfDictionaries> dictionaryRemove(
    MdfDictKind kind,
    String option,
  ) async {
    lists[kind]!.removeWhere((e) => e.id == option);
    return _now;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a choice keeps the value an order already has', () {
    expect(mdfChoices(['R3'], 'R8'), ['R3', 'R8']);
    expect(mdfChoices(['R3'], 'R3'), ['R3']);
    expect(mdfChoices(['R3'], null), ['R3']);
    expect(thicknessOf('16 мм'), 16);
    expect(thicknessOf('—'), isNull);
  });

  testWidgets('add, rename, delete and choose in one list', (tester) async {
    final repo = _FakeRepository();
    String? chosen = 'none';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mdfOrderRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => chosen = await showMdfDictionary(
                context,
                MdfDictKind.patina,
                title: 'Patina',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dictEntry:Жоқ/Нет')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dictAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dictValue')), 'Алтын');
    await tester.tap(find.byKey(const ValueKey('dictSave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dictEntry:Алтын')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dictEdit:Алтын')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dictValue')), 'Күміс');
    await tester.tap(find.byKey(const ValueKey('dictSave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dictEntry:Күміс')), findsOneWidget);
    expect(find.byKey(const ValueKey('dictEntry:Алтын')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dictDelete:Жоқ/Нет')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dictDeleteYes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dictEntry:Жоқ/Нет')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dictEntry:Күміс')));
    await tester.pumpAndSettle();
    expect(chosen, 'Күміс');
  });
}
