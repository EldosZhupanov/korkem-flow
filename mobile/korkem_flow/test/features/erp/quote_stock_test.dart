import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/features/quotes/data/quote_repository.dart';
import 'package:korkem_flow/features/quotes/domain/quote.dart';
import 'package:korkem_flow/features/warehouse/data/stock_repository.dart';

void main() {
  group('Quote', () {
    Quote quote({String status = 'Open', String? validTill}) {
      // The shape a live /api/resource/Quotation response actually returns.
      return QuoteRepository.fromJson({
        'name': '_T-Quotation-00014',
        'status': status,
        'docstatus': 1,
        'customer_name': 'Астана Мебель Групп',
        'party_name': 'Астана Мебель Групп',
        'transaction_date': '2026-07-24',
        'valid_till': validTill,
        'grand_total': 4850000.0,
        'currency': 'KZT',
        'total_qty': 10.0,
      });
    }

    final now = DateTime(2026, 7, 28, 11);

    test('maps the live payload', () {
      final q = quote(validTill: '2026-08-03');

      expect(q.id, '_T-Quotation-00014');
      expect(q.status, QuoteStatus.open);
      expect(q.docStatus, 1);
      expect(q.isDraft, isFalse);
      expect(q.grandTotal, 4850000.0);
      expect(q.displayName, 'Астана Мебель Групп');
    });

    test('falls back through customer, party, then id for a display name', () {
      final bare = QuoteRepository.fromJson({'name': 'Q-1', 'status': 'Draft'});

      expect(bare.displayName, 'Q-1');
    });

    test('a lapsed validity is expired even while the wire says Open', () {
      // ERPNext only rewrites `status` to Expired on a scheduled job, so a
      // quote reads "Open" for hours after it stopped being one. Trusting the
      // field alone would have a salesperson quoting a dead price.
      expect(quote(validTill: '2026-07-20').isExpiredAt(now), isTrue);
      expect(quote(validTill: '2026-08-03').isExpiredAt(now), isFalse);
    });

    test('a closed quote never reads as expired', () {
      // Ordered work is done; relabelling it "expired" would be wrong twice.
      expect(
        quote(status: 'Ordered', validTill: '2026-07-20').isExpiredAt(now),
        isFalse,
      );
      expect(
        quote(status: 'Lost', validTill: '2026-07-20').isExpiredAt(now),
        isFalse,
      );
    });

    test('expiresSoon covers the week before, and not after', () {
      expect(quote(validTill: '2026-08-03').expiresSoon(now), isTrue);
      // Already gone — that is expired, not expiring.
      expect(quote(validTill: '2026-07-20').expiresSoon(now), isFalse);
      // Still a month out.
      expect(quote(validTill: '2026-09-01').expiresSoon(now), isFalse);
      // No deadline at all.
      expect(quote().expiresSoon(now), isFalse);
    });

    test('statuses carry the right intent', () {
      expect(QuoteStatus.fromWire('Ordered').intent, StatusIntent.success);
      expect(QuoteStatus.fromWire('Lost').intent, StatusIntent.danger);
      expect(QuoteStatus.fromWire('Partially Ordered').isClosed, isFalse);
      expect(QuoteStatus.fromWire('Nonsense'), QuoteStatus.draft);
    });
  });

  group('StockItem', () {
    test('maps the live payload, including Check fields as 0/1', () {
      final item = StockRepository.itemFromJson({
        'name': 'MDF Panel',
        'item_name': 'MDF Panel',
        'item_group': 'Raw Material',
        'stock_uom': 'Nos',
        'is_stock_item': 1,
        'disabled': 0,
        'valuation_rate': 0.0,
      });

      expect(item.id, 'MDF Panel');
      expect(item.isStockItem, isTrue);
      expect(item.disabled, isFalse);
    });

    test('is_stock_item defaults to true when absent', () {
      // Getting this backwards would hide the balance section on every item.
      final item = StockRepository.itemFromJson({'name': 'X'});

      expect(item.isStockItem, isTrue);
      expect(item.name, 'X', reason: 'falls back to the item code');
    });

    test('accepts Check fields sent as strings', () {
      final item = StockRepository.itemFromJson({
        'name': 'X',
        'is_stock_item': '0',
        'disabled': '1',
      });

      expect(item.isStockItem, isFalse);
      expect(item.disabled, isTrue);
    });
  });

  group('StockBalance', () {
    test('available is physical stock minus what is already committed', () {
      // What can still be promised to a customer — the number a salesperson
      // is actually asking for. Showing actual_qty would over-promise.
      final balance = StockRepository.balanceFromJson({
        'warehouse': 'Готовая продукция — KRK',
        'actual_qty': 124.0,
        'reserved_qty': 40.0,
        'projected_qty': 84.0,
      });

      expect(balance.actualQty, 124);
      expect(balance.availableQty, 84);
    });

    test('fully reserved stock is zero available, not zero on hand', () {
      final balance = StockRepository.balanceFromJson({
        'warehouse': 'Сырьё — KRK',
        'actual_qty': 6.0,
        'reserved_qty': 6.0,
      });

      expect(balance.actualQty, 6);
      expect(balance.availableQty, 0);
    });
  });
}
