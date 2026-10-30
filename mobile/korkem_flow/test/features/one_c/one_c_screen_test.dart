import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/one_c/data/one_c_repository.dart';
import 'package:korkem_flow/features/one_c/domain/one_c.dart';
import 'package:korkem_flow/features/one_c/presentation/one_c_screen.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';

import '../../support/widget_harness.dart';

class _FakeOneC implements OneCRepository {
  _FakeOneC({this.canEdit = true});

  bool enabled = true;
  final bool canEdit;
  final exported = <(String, PayPeriod)>[];

  OneCSettings get _settings => OneCSettings(
    enabled: enabled,
    canEdit: canEdit,
    tables: const [
      (table: 'sales', title: 'Реализация'),
      (table: 'payroll', title: 'Ведомость'),
    ],
  );

  @override
  Future<OneCSettings> settings() async => _settings;

  @override
  Future<OneCSettings> setEnabled({required bool enabled}) async {
    this.enabled = enabled;
    return _settings;
  }

  @override
  Future<OneCExport> export(String table, PayPeriod period) async {
    exported.add((table, period));
    return const OneCExport(
      table: 'sales',
      rows: 3,
      filename: '1c_sales.csv',
      csv: '﻿Дата;Номер\r\n',
    );
  }
}

void main() {
  late String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  Future<_FakeOneC> pump(WidgetTester tester, _FakeOneC repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [oneCRepositoryProvider.overrideWithValue(repo)],
        child: harness(const OneCScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('a table for the month is copied for 1C', (tester) async {
    final repo = await pump(tester, _FakeOneC());
    await tester.tap(find.byKey(const ValueKey('oneCCopy:sales')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(repo.exported.single.$1, 'sales');
    expect(repo.exported.single.$2, monthOf(DateTime(now.year, now.month)));
    expect(clipboard, startsWith('﻿Дата;Номер'));
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('switched off, it offers nothing to copy', (tester) async {
    final repo = await pump(tester, _FakeOneC());
    await tester.tap(find.byKey(const ValueKey('oneCEnabled')));
    await tester.pumpAndSettle();

    expect(repo.enabled, isFalse);
    expect(find.byKey(const ValueKey('oneCCopy:sales')), findsNothing);
  });

  testWidgets('only the people who may switch it see the switch work', (
    tester,
  ) async {
    final repo = await pump(tester, _FakeOneC(canEdit: false));
    await tester.tap(find.byKey(const ValueKey('oneCEnabled')));
    await tester.pumpAndSettle();
    expect(repo.enabled, isTrue);
  });

  test('settings read the server tables in order', () {
    final settings = OneCSettings.fromJson(const {
      'enabled': true,
      'can_edit': false,
      'tables': [
        {'table': 'sales', 'title': 'Реализация'},
        {'table': 'payments', 'title': 'Оплаты'},
      ],
    });
    expect(settings.tables.map((t) => t.table), ['sales', 'payments']);
    expect(settings.canEdit, isFalse);
  });
}
