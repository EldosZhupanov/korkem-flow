import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/deals/data/deal_dto.dart';

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
      expect(deal.status, 'Proposal/Quotation');
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

    test('preserves a stage this build has never heard of', () {
      final deal = DealDto.fromJson({
        'name': 'X',
        'organization': 'Acme',
        'status': 'Замер',
      });

      // Regression guard. An earlier version parsed status into an enum and
      // fell back to Qualification on no match — so the day an administrator
      // added a stage, every deal in it would have displayed as "Qualification"
      // and any status write would have moved it there for real. Stage names
      // are data now, and data is carried, not guessed at.
      expect(deal.status, 'Замер');
    });

    test('survives a null organization', () {
      final deal = DealDto.fromJson({'name': 'X', 'status': 'Won'});

      expect(deal.organization, '—');
      expect(deal.status, 'Won');
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
}
