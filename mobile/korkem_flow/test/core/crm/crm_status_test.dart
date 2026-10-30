import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/crm/status_catalog_repository.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

/// The stage rows this site actually holds, read live from
/// `/api/resource/CRM Deal Status` on 2026-07-28.
const _liveDealRows = <Map<String, Object>>[
  {'name': 'Qualification', 'type': 'Open', 'position': 1},
  {'name': 'Demo/Making', 'type': 'Ongoing', 'position': 2},
  {'name': 'Proposal/Quotation', 'type': 'Ongoing', 'position': 3},
  {'name': 'Negotiation', 'type': 'Ongoing', 'position': 4},
  {'name': 'Ready to Close', 'type': 'Ongoing', 'position': 5},
  {'name': 'Won', 'type': 'Won', 'position': 6},
  {'name': 'Lost', 'type': 'Lost', 'position': 7},
];

void main() {
  setUpAll(() {
    registerFallbackValue(const FrappeQuery());
  });

  group('CrmStatusType', () {
    test('maps each configured type onto a design-system intent', () {
      expect(CrmStatusType.fromWire('Won').intent, StatusIntent.success);
      expect(CrmStatusType.fromWire('Lost').intent, StatusIntent.danger);
      expect(CrmStatusType.fromWire('Ongoing').intent, StatusIntent.info);
      expect(CrmStatusType.fromWire('On Hold').intent, StatusIntent.warning);
      expect(CrmStatusType.fromWire('Open').intent, StatusIntent.neutral);
    });

    test('falls back to Open for a type this build does not know', () {
      // The Select's options are editable too. An unknown type must still
      // render — just without the app claiming to know what it means.
      expect(CrmStatusType.fromWire('Escalated'), CrmStatusType.open);
      expect(CrmStatusType.fromWire(null), CrmStatusType.open);
    });

    test('isClosed covers exactly the terminal types', () {
      expect(CrmStatusType.won.isClosed, isTrue);
      expect(CrmStatusType.lost.isClosed, isTrue);
      expect(CrmStatusType.onHold.isClosed, isFalse);
      expect(CrmStatusType.ongoing.isClosed, isFalse);
    });
  });

  group('StatusCatalog', () {
    const catalog = StatusCatalog([
      CrmStatus(name: 'Won', type: CrmStatusType.won, position: 6),
    ]);

    test('resolves a configured stage', () {
      expect(catalog.resolve('Won').intent, StatusIntent.success);
    });

    test('resolves an unlisted stage to itself rather than dropping it', () {
      // A record whose stage was later deleted from settings must still show
      // what it actually holds; hiding it would misrepresent the record.
      final resolved = catalog.resolve('Замер');

      expect(resolved.name, 'Замер');
      expect(resolved.intent, StatusIntent.neutral);
    });

    test('treats a missing stage as blank, not as a stage named "null"', () {
      expect(catalog.resolve(null).name, '');
      expect(catalog.resolve('').name, '');
    });
  });

  group('StatusCatalogRepository', () {
    test('reads every configured stage, in pipeline order', () async {
      final client = _MockClient();
      when(
        () => client.getList(any(), any()),
      ).thenAnswer((_) async => List<Map<String, dynamic>>.from(_liveDealRows));

      final catalog = await StatusCatalogRepository(
        client,
      ).fetch(StatusCatalogRepository.dealStatusDoctype);

      expect(catalog.statuses, hasLength(7));
      expect(catalog.statuses.first.name, 'Qualification');
      expect(catalog.resolve('Ready to Close').type, CrmStatusType.ongoing);
      expect(catalog.resolve('Won').type, CrmStatusType.won);
    });

    test('asks for the whole catalogue, not a first page', () async {
      // A truncated catalogue silently hides stages from the filter sheet.
      final client = _MockClient();
      when(() => client.getList(any(), any())).thenAnswer((_) async => []);

      await StatusCatalogRepository(client).fetch('CRM Lead Status');

      final query =
          verify(() => client.getList(any(), captureAny())).captured.single
              as FrappeQuery;
      expect(query.limitPageLength, 0);
      expect(query.orderBy, 'position asc');
    });

    test('parses a position that arrives as a string', () async {
      final client = _MockClient();
      when(() => client.getList(any(), any())).thenAnswer(
        (_) async => [
          {'name': 'New', 'type': 'Open', 'position': '1'},
        ],
      );

      final catalog = await StatusCatalogRepository(
        client,
      ).fetch('CRM Lead Status');

      expect(catalog.statuses.single.position, 1);
    });
  });
}
