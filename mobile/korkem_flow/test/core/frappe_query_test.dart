import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';

void main() {
  group('FrappeQuery wire format', () {
    test('encodes fields as a JSON array string, not repeated params', () {
      const query = FrappeQuery(fields: ['name', 'status']);

      final params = query.toQueryParameters();

      // Frappe rejects repeated `fields` params; it wants one JSON string.
      expect(params['fields'], isA<String>());
      expect(jsonDecode(params['fields']! as String), ['name', 'status']);
    });

    test('encodes filters as an array of [field, operator, value] triples', () {
      const query = FrappeQuery(
        filters: [
          FrappeFilter.equals('status', 'Won'),
          FrappeFilter.like('organization', '%acme%'),
        ],
      );

      final decoded =
          jsonDecode(query.toQueryParameters()['filters']! as String) as List;

      expect(decoded, [
        ['status', '=', 'Won'],
        ['organization', 'like', '%acme%'],
      ]);
    });

    test('omits filters entirely when there are none', () {
      const query = FrappeQuery();

      expect(query.toQueryParameters().containsKey('filters'), isFalse);
    });

    test('omits order_by when unset', () {
      const query = FrappeQuery();

      expect(query.toQueryParameters().containsKey('order_by'), isFalse);
    });

    test('nextPage advances limit_start by exactly one page', () {
      const first = FrappeQuery();

      final second = first.nextPage();
      final third = second.nextPage();

      expect(first.limitStart, 0);
      expect(second.limitStart, 20);
      expect(third.limitStart, 40);
    });

    test('isIn serialises a list value', () {
      const query = FrappeQuery(
        filters: [
          FrappeFilter.isIn('status', ['Won', 'Lost']),
        ],
      );

      final decoded =
          jsonDecode(query.toQueryParameters()['filters']! as String) as List;

      expect(decoded.first, [
        'status',
        'in',
        ['Won', 'Lost'],
      ]);
    });

    test('signature distinguishes queries that address different data', () {
      const a = FrappeQuery(filters: [FrappeFilter.equals('status', 'Won')]);
      const b = FrappeQuery(filters: [FrappeFilter.equals('status', 'Lost')]);
      const c = FrappeQuery(filters: [FrappeFilter.equals('status', 'Won')]);

      // Cache correctness depends on this: a filtered list must not overwrite
      // the cache entry of a differently-filtered list.
      expect(a.signature, isNot(b.signature));
      expect(a.signature, c.signature);
    });
  });
}
