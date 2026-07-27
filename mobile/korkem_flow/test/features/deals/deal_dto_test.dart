import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/deals/data/deal_dto.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';

void main() {
  group('DealDto.fromJson', () {
    test('maps a real payload shape from /api/resource/CRM Deal', () {
      // This is the shape actually returned by the running backend.
      final deal = DealDto.fromJson({
        'name': 'CRM-DEAL-2026-00001',
        'organization': 'Chi Systems',
        'status': 'Proposal/Quotation',
        'next_step': 'kitchen facades (qty 8)',
        'mobile_no': '77010001122',
        'modified': '2026-07-27 18:22:10.123456',
      });

      expect(deal.id, 'CRM-DEAL-2026-00001');
      expect(deal.organization, 'Chi Systems');
      expect(deal.status, DealStatus.proposal);
      expect(deal.nextStep, 'kitchen facades (qty 8)');
      expect(deal.mobileNo, '77010001122');
      expect(deal.modified?.year, 2026);
    });

    test('treats empty strings as null — Frappe sends "" for unset fields', () {
      final deal = DealDto.fromJson({
        'name': 'CRM-DEAL-2026-00002',
        'organization': 'Acme',
        'status': 'Qualification',
        'next_step': '',
        'mobile_no': '',
      });

      expect(deal.nextStep, isNull);
      expect(deal.mobileNo, isNull);
    });

    test('throws when the payload has no name rather than inventing one', () {
      expect(
        () => DealDto.fromJson({'organization': 'Acme'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to qualification for an unrecognised status', () {
      final deal = DealDto.fromJson({
        'name': 'X',
        'organization': 'Acme',
        'status': 'Some Future Status',
      });

      // Must degrade gracefully: a new status configured server-side should
      // not crash the list.
      expect(deal.status, DealStatus.qualification);
    });

    test('survives a null organization', () {
      final deal = DealDto.fromJson({'name': 'X', 'status': 'Won'});

      expect(deal.organization, '—');
      expect(deal.status, DealStatus.won);
    });

    test('stringifies a non-string name', () {
      // CRM Task uses autoincrement naming (int). The same mapper style must
      // not assume String ids.
      final deal = DealDto.fromJson({'name': 42, 'status': 'Won'});

      expect(deal.id, '42');
    });

    test('tolerates an unparseable modified timestamp', () {
      final deal = DealDto.fromJson({
        'name': 'X',
        'status': 'Won',
        'modified': 'not-a-date',
      });

      expect(deal.modified, isNull);
    });
  });

  group('DealStatus', () {
    test('every seeded backend status maps to an enum value', () {
      // Verified live against /api/resource/CRM Deal Status.
      const seeded = [
        'Qualification',
        'Demo/Making',
        'Proposal/Quotation',
        'Negotiation',
        'Ready to Close',
        'Won',
        'Lost',
      ];

      for (final value in seeded) {
        expect(
          DealStatus.fromWire(value),
          isNotNull,
          reason: '"$value" exists on the backend but has no enum mapping',
        );
      }
    });

    test('wireValue round-trips', () {
      for (final status in DealStatus.values) {
        expect(DealStatus.fromWire(status.wireValue), status);
      }
    });

    test('isClosed is true only for Won and Lost', () {
      expect(DealStatus.won.isClosed, isTrue);
      expect(DealStatus.lost.isClosed, isTrue);
      expect(DealStatus.negotiation.isClosed, isFalse);
    });
  });
}
