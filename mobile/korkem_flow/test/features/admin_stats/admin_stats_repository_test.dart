import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/admin_stats/data/admin_stats_repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Map<String, dynamic> data, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(data),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

void main() {
  Dio createDio(Future<ResponseBody> Function(RequestOptions options) handler) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
      ),
    )..httpClientAdapter = _FakeAdapter(handler);
  }

  group('AdminStatsRepository', () {
    test('fetches and parses stats with custom days parameter', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.capture.stats',
        );
        expect(options.queryParameters['days'], 30);
        return _json({
          'message': {
            'days': 30,
            'caught': 47,
            'handed_over': 45,
            'converted': 12,
            'dismissed': 3,
            'stale': 2,
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = AdminStatsRepository(client);

      final stats = await repo.getStats();

      expect(stats.days, 30);
      expect(stats.caught, 47);
      expect(stats.handedOver, 45);
      expect(stats.converted, 12);
      expect(stats.dismissed, 3);
      expect(stats.stale, 2);
      expect(stats.isEmpty, isFalse);
    });

    test('parses empty stats correctly', () async {
      final dio = createDio((options) async {
        return _json({
          'message': {
            'days': 7,
            'caught': 0,
            'handed_over': 0,
            'converted': 0,
            'dismissed': 0,
            'stale': 0,
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = AdminStatsRepository(client);

      final stats = await repo.getStats(days: 7);

      expect(stats.days, 7);
      expect(stats.caught, 0);
      expect(stats.stale, 0);
      expect(stats.isEmpty, isTrue);
    });
  });
}
