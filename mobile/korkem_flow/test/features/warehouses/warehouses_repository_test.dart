import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/warehouses/data/warehouses_repository.dart';
import 'package:korkem_flow/features/warehouses/domain/warehouse_models.dart';

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

  group('Warehouse domain models', () {
    test('WarehouseEntry serialization, copyWith, and equality', () {
      const entry1 = WarehouseEntry(
        warehouse: 'Finished Goods - ED',
        name: 'Finished Goods',
        disabled: false,
        positions: 12,
        isShippingDefault: true,
      );

      final entry2 = entry1.copyWith(positions: 0, isShippingDefault: false);
      expect(entry2.positions, 0);
      expect(entry2.isShippingDefault, isFalse);
      expect(entry2.warehouse, 'Finished Goods - ED');

      final fromJson = WarehouseEntry.fromJson(const {
        'warehouse': 'Finished Goods - ED',
        'name': 'Finished Goods',
        'disabled': false,
        'positions': 12,
        'is_shipping_default': true,
      });

      expect(fromJson, entry1);
      expect(fromJson.hashCode, entry1.hashCode);
    });

    test('WarehouseEntry handles zero positions and string positions', () {
      final entryZero = WarehouseEntry.fromJson(const {
        'message': {
          'warehouse': 'Склад материалов - ED',
          'name': 'Склад материалов',
          'disabled': 0,
          'positions': 0,
          'is_shipping_default': 0,
        },
      });

      expect(entryZero.positions, 0);
      expect(entryZero.disabled, isFalse);
      expect(entryZero.isShippingDefault, isFalse);

      final entryString = WarehouseEntry.fromJson(const {
        'data': {
          'warehouse': 'Склад - ED',
          'name': 'Склад',
          'disabled': 1,
          'positions': '5',
          'is_shipping_default': 1,
        },
      });

      expect(entryString.positions, 5);
      expect(entryString.disabled, isTrue);
      expect(entryString.isShippingDefault, isTrue);
    });
  });

  group('WarehousesRepository', () {
    test('fetchWarehouses fetches and parses warehouse listing', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.warehouses.listing',
        );
        return _json({
          'message': [
            {
              'warehouse': 'Finished Goods - ED',
              'name': 'Finished Goods',
              'disabled': false,
              'positions': 12,
              'is_shipping_default': true,
            },
            {
              'warehouse': 'Stores - ED',
              'name': 'Stores',
              'disabled': false,
              'positions': 0,
              'is_shipping_default': false,
            },
          ],
        });
      });

      final repo = WarehousesRepository(FrappeClient(dio));
      final warehouses = await repo.fetchWarehouses();

      expect(warehouses.length, 2);
      expect(warehouses[0].warehouse, 'Finished Goods - ED');
      expect(warehouses[0].name, 'Finished Goods');
      expect(warehouses[0].positions, 12);
      expect(warehouses[0].isShippingDefault, isTrue);
      expect(warehouses[0].disabled, isFalse);

      expect(warehouses[1].warehouse, 'Stores - ED');
      expect(warehouses[1].positions, 0);
      expect(warehouses[1].isShippingDefault, isFalse);
    });

    test('fetchWarehouses throws ServerFailure on non-list response', () async {
      final dio = createDio((_) async => _json({'message': 'unexpected'}));
      final repo = WarehousesRepository(FrappeClient(dio));

      await expectLater(
        repo.fetchWarehouses(),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('createWarehouse sends name and returns created warehouse', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.warehouses.create',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['name'], 'Склад материалов');

        return _json({
          'message': {
            'warehouse': 'Склад материалов - ED',
            'name': 'Склад материалов',
            'disabled': false,
            'positions': 0,
            'is_shipping_default': false,
          },
        });
      });

      final repo = WarehousesRepository(FrappeClient(dio));
      final created = await repo.createWarehouse(name: 'Склад материалов');

      expect(created.warehouse, 'Склад материалов - ED');
      expect(created.name, 'Склад материалов');
      expect(created.disabled, isFalse);
      expect(created.positions, 0);
      expect(created.isShippingDefault, isFalse);
    });

    test('createWarehouse validates non-empty name', () async {
      final repo = WarehousesRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.createWarehouse(name: '   '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      'createWarehouse throws ServerFailure on unexpected response',
      () async {
        final dio = createDio((options) async => _json({'message': null}));
        final repo = WarehousesRepository(FrappeClient(dio));

        expect(
          () => repo.createWarehouse(name: 'Цех 2'),
          throwsA(isA<ServerFailure>()),
        );
      },
    );

    test(
      'setShippingDefault sends warehouse and returns updated record',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.warehouses.set_shipping_default',
          );
          final data = options.data as Map<String, dynamic>;
          expect(data['warehouse'], 'Склад готовой продукции - ED');

          return _json({
            'message': {
              'warehouse': 'Склад готовой продукции - ED',
              'name': 'Склад готовой продукции',
              'disabled': false,
              'positions': 5,
              'is_shipping_default': true,
            },
          });
        });

        final repo = WarehousesRepository(FrappeClient(dio));
        final updated = await repo.setShippingDefault(
          warehouse: 'Склад готовой продукции - ED',
        );

        expect(updated.isShippingDefault, isTrue);
        expect(updated.name, 'Склад готовой продукции');
      },
    );

    test('setShippingDefault validates non-empty warehouse', () async {
      final repo = WarehousesRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.setShippingDefault(warehouse: ''),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('setDisabled sends warehouse and disabled flag', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.warehouses.set_disabled',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['warehouse'], 'Stores - ED');
        expect(data['disabled'], true);

        return _json({
          'message': {
            'warehouse': 'Stores - ED',
            'name': 'Stores',
            'disabled': true,
            'positions': 0,
            'is_shipping_default': false,
          },
        });
      });

      final repo = WarehousesRepository(FrappeClient(dio));
      final updated = await repo.setDisabled(
        warehouse: 'Stores - ED',
        disabled: true,
      );

      expect(updated.disabled, isTrue);
      expect(updated.warehouse, 'Stores - ED');
    });

    test('setDisabled validates non-empty warehouse', () async {
      final repo = WarehousesRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.setDisabled(warehouse: '  ', disabled: true),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
