import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/items/data/items_repository.dart';
import 'package:korkem_flow/features/items/domain/item.dart';

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

  group('Item domain model', () {
    test('serializes and deserializes correctly with sale price', () {
      const item = Item(
        code: 'CAB-01',
        name: 'Шкаф распашной',
        unit: 'Nos',
        description: 'Двухдверный, ЛДСП',
        salePrice: 150000,
      );

      final json = item.toJson();
      final fromJson = Item.fromJson(json);

      expect(fromJson, item);
      expect(fromJson.code, 'CAB-01');
      expect(fromJson.name, 'Шкаф распашной');
      expect(fromJson.unit, 'Nos');
      expect(fromJson.description, 'Двухдверный, ЛДСП');
      expect(fromJson.salePrice, 150000);
    });

    test('supports items without sale price (null price)', () {
      const item = Item(
        code: 'CUSTOM-01',
        name: 'Кухня по индивидуальному проекту',
        unit: 'Set',
      );

      final json = item.toJson();
      expect(json.containsKey('price'), isFalse);

      final fromJson = Item.fromJson(json);
      expect(fromJson.salePrice, isNull);
      expect(fromJson.unit, 'Set');
    });

    test('supports alternative ERPNext DocType keys', () {
      final fromJson = Item.fromJson(const {
        'item_code': 'TBL-02',
        'item_name': 'Стол обеденный',
        'stock_uom': 'Nos',
        'price': 45000,
        'description': 'Массив сосны',
      });

      expect(fromJson.code, 'TBL-02');
      expect(fromJson.name, 'Стол обеденный');
      expect(fromJson.unit, 'Nos');
      expect(fromJson.salePrice, 45000);
      expect(fromJson.description, 'Массив сосны');
    });
  });

  group('UnitOption domain model', () {
    test('serializes and deserializes correctly', () {
      const unit = UnitOption(unit: 'Nos', label: 'шт');
      final json = unit.toJson();
      final fromJson = UnitOption.fromJson(json);

      expect(fromJson, unit);
      expect(fromJson.unit, 'Nos');
      expect(fromJson.label, 'шт');
    });
  });

  group('ItemsRepository', () {
    test('list fetches items from catalogue.items endpoint', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.catalogue.items',
        );
        return _json({
          'message': [
            {
              'code': 'ITEM-01',
              'name': 'Стол письменный',
              'unit': 'Nos',
              'price': 75000,
            },
            {
              'code': 'ITEM-02',
              'name': 'Стеллаж',
              'unit': 'Nos',
              'price': null,
            },
          ],
        });
      });

      final repo = ItemsRepository(FrappeClient(dio));
      final items = await repo.list();

      expect(items.length, 2);
      expect(items[0].code, 'ITEM-01');
      expect(items[0].salePrice, 75000);
      expect(items[1].code, 'ITEM-02');
      expect(items[1].salePrice, isNull);
    });

    test('list passes query parameter when provided', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.catalogue.items',
        );
        expect(options.queryParameters['query'], 'Шкаф');
        return _json({
          'message': [
            {
              'code': 'CAB-01',
              'name': 'Шкаф',
              'unit': 'Nos',
              'price': 450000,
            },
          ],
        });
      });

      final repo = ItemsRepository(FrappeClient(dio));
      final items = await repo.list(query: 'Шкаф');

      expect(items.length, 1);
      expect(items[0].name, 'Шкаф');
    });

    test('list throws ServerFailure on unexpected non-list response', () async {
      final dio = createDio((options) async {
        return _json({'message': 'unexpected string'});
      });

      final repo = ItemsRepository(FrappeClient(dio));
      expect(repo.list, throwsA(isA<ServerFailure>()));
    });

    test('create rejects item without unit of measure', () async {
      final repo = ItemsRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.create(
          const Item(
            code: 'IT-1',
            name: 'Стул',
            unit: '  ',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('create rejects item without name', () async {
      final repo = ItemsRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.create(
          const Item(
            code: 'IT-1',
            name: '',
            unit: 'Nos',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      'create sends correct payload to catalogue.create',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.catalogue.create',
          );
          final data = options.data as Map<String, dynamic>;
          expect(data['name'], 'Комод 4 ящика');
          expect(data['unit'], 'Nos');
          expect(data['code'], 'DRW-04');
          expect(data['price'], 89000);

          return _json({
            'message': {
              'code': 'DRW-04',
              'name': 'Комод 4 ящика',
              'unit': 'Nos',
              'price': 89000,
            },
          });
        });

        final repo = ItemsRepository(FrappeClient(dio));
        final created = await repo.create(
          const Item(
            code: 'DRW-04',
            name: 'Комод 4 ящика',
            unit: 'Nos',
            salePrice: 89000,
          ),
        );

        expect(created.code, 'DRW-04');
        expect(created.name, 'Комод 4 ящика');
        expect(created.salePrice, 89000);
      },
    );

    test('create creates item without price (price is null)', () async {
      final dio = createDio((options) async {
        final data = options.data as Map<String, dynamic>;
        expect(data.containsKey('price'), isFalse);

        return _json({
          'message': {
            'code': 'Кухонный гарнитур',
            'name': 'Кухонный гарнитур',
            'unit': 'Nos',
            'price': null,
          },
        });
      });

      final repo = ItemsRepository(FrappeClient(dio));
      final created = await repo.create(
        const Item(
          code: '',
          name: 'Кухонный гарнитур',
          unit: 'Nos',
        ),
      );

      expect(created.name, 'Кухонный гарнитур');
      expect(created.salePrice, isNull);
    });

    test('create throws ServerFailure on empty server confirmation', () async {
      final dio = createDio((options) async {
        return _json({'message': <String, dynamic>{}});
      });

      final repo = ItemsRepository(FrappeClient(dio));
      expect(
        () => repo.create(
          const Item(
            code: 'IT-1',
            name: 'Стол',
            unit: 'Nos',
          ),
        ),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('setPrice sends code and price to catalogue.set_price', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.catalogue.set_price',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['code'], 'CAB-01');
        expect(data['price'], 450000);

        return _json({
          'message': {
            'code': 'CAB-01',
            'name': 'Шкаф',
            'unit': 'Nos',
            'price': 450000,
          },
        });
      });

      final repo = ItemsRepository(FrappeClient(dio));
      final updated = await repo.setPrice('CAB-01', 450000);

      expect(updated.code, 'CAB-01');
      expect(updated.salePrice, 450000);
    });

    test('setPrice throws ServerFailure on unexpected response', () async {
      final dio = createDio((options) async {
        return _json({'message': null});
      });

      final repo = ItemsRepository(FrappeClient(dio));
      expect(
        () => repo.setPrice('CAB-01', 50000),
        throwsA(isA<ServerFailure>()),
      );
    });

    test(
      'fetchUnits returns list of UnitOptions in order from catalogue.units',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.catalogue.units',
          );
          return _json({
            'message': [
              {'unit': 'Nos', 'label': 'шт'},
              {'unit': 'Set', 'label': 'комплект'},
              {'unit': 'Meter', 'label': 'м, погонный метр'},
              {'unit': 'Square Meter', 'label': 'м², квадратный метр'},
              {'unit': 'Sheet', 'label': 'лист'},
              {'unit': 'Pair', 'label': 'пара'},
              {'unit': 'Kg', 'label': 'кг'},
            ],
          });
        });

        final repo = ItemsRepository(FrappeClient(dio));
        final units = await repo.fetchUnits();

        expect(units.length, 7);
        expect(units[0].unit, 'Nos');
        expect(units[0].label, 'шт');
        expect(units[1].unit, 'Set');
        expect(units[1].label, 'комплект');
        expect(units[2].unit, 'Meter');
      },
    );

    test(
      'fetchUnits throws ServerFailure when server returns non-list',
      () async {
        final dio = createDio((options) async {
          return _json({'message': 'not a list'});
        });

        final repo = ItemsRepository(FrappeClient(dio));
        expect(repo.fetchUnits, throwsA(isA<ServerFailure>()));
      },
    );
  });

  group('цена ноль и цена не названа', () {
    // Найдено мутацией: если `Item.fromJson` начнёт превращать ноль в null,
    // ни один из 740 тестов не упадёт — во всех фикстурах цена либо большая,
    // либо отсутствует. Ноль не встречался нигде, а это разные вещи:
    // ноль значит «бесплатно» (образец, подарок к заказу), null — «ещё не
    // считали», что для мебели на заказ нормальное состояние.
    test('ноль остаётся нулём, а не превращается в «цену по расчёту»', () {
      final item = Item.fromJson(const {
        'code': 'SAMPLE-01',
        'name': 'Образец фасада МДФ',
        'unit': 'Nos',
        'price': 0,
      });

      expect(item.salePrice, 0.0);
      expect(item.salePrice, isNotNull);
    });

    test('отсутствие цены остаётся отсутствием, а не нулём', () {
      final item = Item.fromJson(const {
        'code': 'KITCHEN-01',
        'name': 'Кухонный гарнитур',
        'unit': 'Nos',
        'price': null,
      });

      expect(item.salePrice, isNull);
    });

    test('ноль строкой — тоже ноль', () {
      final item = Item.fromJson(const {
        'code': 'SAMPLE-02',
        'name': 'Образец кромки',
        'unit': 'Meter',
        'price': '0',
      });

      expect(item.salePrice, 0.0);
    });
  });
}
