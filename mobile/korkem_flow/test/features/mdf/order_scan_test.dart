import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/data/my_work_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/my_work.dart';
import 'package:korkem_flow/features/mdf/domain/order_scan.dart';
import 'package:korkem_flow/features/mdf/presentation/order_scan_listener.dart';
import 'package:korkem_flow/features/mdf/presentation/order_scan_sheet.dart';

import '../../support/widget_harness.dart';

const _order = 'SAL-ORD-2026-00245';

class _Fake implements MyWorkRepository {
  final codes = <String>[];
  final ticks = <(MdfStage, bool)>[];
  String? cutOn;

  Map<String, Object?> _scan() => {
    'order': _order,
    'customer': 'Ерлан Абенов',
    'decor': 'Белый матовый',
    'delivery_date': '2026-11-21',
    'area_m2': 3.04,
    'manager': false,
    'stages': [
      {
        'stage': 'cut',
        'done_on': cutOn,
        'mine': true,
        'by_me': cutOn != null,
        'waiting_for': const <String>[],
      },
      {
        'stage': 'mill',
        'done_on': null,
        'mine': false,
        'waiting_for': [if (cutOn == null) 'cut'],
      },
    ],
  };

  @override
  Future<OrderScan> scan(String code) async {
    codes.add(code);
    return OrderScan.fromJson(_scan());
  }

  @override
  Future<OrderScan> tick(
    String order,
    MdfStage stage, {
    bool undo = false,
  }) async {
    ticks.add((stage, undo));
    cutOn = undo ? null : '2026-11-18';
    return OrderScan.fromJson(_scan());
  }

  @override
  Future<MyWork> work() async => const MyWork(name: 'Ерлан');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Types [text] as a scanner does: every key, Shift for capitals, a pause
/// of `gapMs` between keys, Enter at the end.
String? _burst(ScanBurst burst, String text, {int gapMs = 10}) {
  var at = Duration.zero;
  String? out;
  void press(PhysicalKeyboardKey key, {bool shift = false}) {
    at += Duration(milliseconds: gapMs);
    out = burst.key(key, shift: shift, at: at);
  }

  for (final char in text.split('')) {
    final upper = char.toUpperCase();
    if (RegExp('[A-Z]').hasMatch(char)) {
      press(PhysicalKeyboardKey.shiftLeft, shift: true);
      press(
        PhysicalKeyboardKey.findKeyByCode(
              PhysicalKeyboardKey.keyA.usbHidUsage +
                  upper.codeUnitAt(0) -
                  'A'.codeUnitAt(0),
            ) ??
            PhysicalKeyboardKey.keyA,
        shift: true,
      );
    } else if (RegExp(r'\d').hasMatch(char)) {
      final n = int.parse(char);
      press(
        n == 0
            ? PhysicalKeyboardKey.digit0
            : PhysicalKeyboardKey.findKeyByCode(
                    PhysicalKeyboardKey.digit1.usbHidUsage + n - 1,
                  ) ??
                  PhysicalKeyboardKey.digit1,
      );
    } else if (char == '-') {
      press(PhysicalKeyboardKey.minus);
    } else if (char == ':') {
      press(PhysicalKeyboardKey.shiftLeft, shift: true);
      press(PhysicalKeyboardKey.semicolon, shift: true);
    }
  }
  press(PhysicalKeyboardKey.enter);
  return out;
}

void main() {
  group('a handheld scanner', () {
    test('its burst is read by the keys, whatever the layout', () {
      expect(
        _burst(ScanBurst(), orderQrData(_order)),
        'KORKEM:ORDER:$_order',
      );
      expect(_burst(ScanBurst(), _order), _order);
    });

    test('a person typing is not a scanner', () {
      expect(_burst(ScanBurst(), orderQrData(_order), gapMs: 200), isNull);
      expect(_burst(ScanBurst(), 'HELLO'), isNull);
    });

    test("an order's number is said as people say it", () {
      expect(orderShortNumber(_order), '245');
      expect(orderShortNumber('SAL-ORD-2026-01000'), '1000');
    });
  });

  testWidgets('a scan shows the stages and ticks the one that is mine', (
    tester,
  ) async {
    final repo = _Fake();
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [myWorkRepositoryProvider.overrideWithValue(repo)],
        child: harness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showOrderScan(context, ' 245 '),
              child: const Text('scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    expect(repo.codes, ['245']);
    expect(find.text('No. 245 · Ерлан Абенов'), findsOneWidget);
    expect(find.byKey(const ValueKey('orderScanDone:cut')), findsOneWidget);
    expect(find.byKey(const ValueKey('orderScanDone:mill')), findsNothing);
    expect(find.byKey(const ValueKey('orderScanOpen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('orderScanDone:cut')));
    await tester.pumpAndSettle();
    expect(repo.ticks, [(MdfStage.cut, false)]);
    expect(find.byKey(const ValueKey('orderScanUndo:cut')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('orderScanUndo:cut')));
    await tester.pumpAndSettle();
    expect(repo.ticks.last, (MdfStage.cut, true));
    expect(find.byKey(const ValueKey('orderScanDone:cut')), findsOneWidget);
  });
}
