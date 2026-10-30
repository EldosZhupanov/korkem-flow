import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/orders/domain/delivery_note.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/price_visibility/data/price_visibility_repository.dart';
import 'package:korkem_flow/features/price_visibility/domain/price_visibility.dart';
import 'package:korkem_flow/features/price_visibility/presentation/price_visibility_tile.dart';

import '../../support/widget_harness.dart';

/// Who sees money is the server's answer. The app draws the switch for the
/// administrator only, and never turns a hidden price into "0 ₸".
class _FakeRepository implements PriceVisibilityRepository {
  _FakeRepository(this.current, {this.failSave = false});

  PriceVisibility current;
  final bool failSave;
  final saved = <bool>[];

  @override
  Future<PriceVisibility> fetch() async => current;

  @override
  Future<PriceVisibility> save({required bool floorSeesPrices}) async {
    saved.add(floorSeesPrices);
    if (failSave) throw const ServerFailure('нет связи');
    return current = PriceVisibility(
      floorSeesPrices: floorSeesPrices,
      youSeePrices: true,
      canChange: true,
    );
  }
}

const _admin = PriceVisibility(
  floorSeesPrices: false,
  youSeePrices: true,
  canChange: true,
);

void main() {
  Future<void> pump(WidgetTester tester, _FakeRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [priceVisibilityRepositoryProvider.overrideWithValue(repo)],
        child: harness(const PriceVisibilityTile()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final tile = find.byKey(const ValueKey('floorSeesPrices'));

  group('PriceVisibility', () {
    test('reads the server answer', () {
      expect(
        PriceVisibility.fromJson(const {
          'floor_sees_prices': true,
          'you_see_prices': false,
          'can_change': false,
        }),
        const PriceVisibility(
          floorSeesPrices: true,
          youSeePrices: false,
          canChange: false,
        ),
      );
    });

    test('a missing answer is "no", never "yes"', () {
      final parsed = PriceVisibility.fromJson(const {});
      expect(parsed.floorSeesPrices, isFalse);
      expect(parsed.canChange, isFalse);
    });
  });

  group('A hidden price stays hidden', () {
    test('an order without a total has no total, not a zero one', () {
      final order = SalesOrder.fromJson(const {
        'name': 'SAL-ORD-1',
        'customer': 'ТОО Мебель',
        'status': 'To Deliver',
        'grand_total': null,
      });
      expect(order.grandTotal, isNull);
      expect(order.advancePaid, isNull);
    });

    test('the same for a delivery', () {
      final delivery = SalesOrderDelivery.fromJson(const {'name': 'DN-1'});
      expect(delivery.grandTotal, isNull);
    });
  });

  group('PriceVisibilityTile', () {
    testWidgets('draws nothing for anybody but the administrator', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeRepository(
          const PriceVisibility(
            floorSeesPrices: false,
            youSeePrices: true,
            canChange: false,
          ),
        ),
      );
      expect(tile, findsNothing);
    });

    testWidgets('the administrator flips it and sees what the server stored', (
      tester,
    ) async {
      final repo = _FakeRepository(_admin);
      await pump(tester, repo);

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(repo.saved, [true]);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    });

    testWidgets('a failed save says so and does not pretend it worked', (
      tester,
    ) async {
      final repo = _FakeRepository(_admin, failSave: true);
      await pump(tester, repo);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
