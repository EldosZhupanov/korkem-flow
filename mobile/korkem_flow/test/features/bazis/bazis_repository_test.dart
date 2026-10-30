import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/bazis/data/bazis_repository.dart';
import 'package:korkem_flow/features/bazis/domain/bazis_models.dart';

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

  group('Bazis domain models', () {
    test('BazisTotals deserialization and equality', () {
      const totals1 = BazisTotals(
        products: 1,
        parts: 10,
        materials: 5,
        operations: 2,
      );

      final fromJson = BazisTotals.fromJson(const {
        'products': '1',
        'parts': 10,
        'materials': 5,
        'operations': '2',
      });

      expect(fromJson, totals1);
      expect(fromJson.hashCode, totals1.hashCode);
    });

    test('BazisPart deserialization with block and edges', () {
      final part = BazisPart.fromJson(const {
        'block': '3 / Шариковые',
        'name': 'Боковина левая',
        'code': 'D-101',
        'kind': 'Панель',
        'length': '2100,5',
        'width': 560,
        'thickness': 16,
        'qty': '2',
        'edges': ['Кромка ПВХ 2мм дуб', 'Кромка ПВХ 0.4мм дуб'],
      });

      expect(part.block, '3 / Шариковые');
      expect(part.name, 'Боковина левая');
      expect(part.code, 'D-101');
      expect(part.kind, 'Панель');
      expect(part.length, 2100.5);
      expect(part.width, 560.0);
      expect(part.thickness, 16.0);
      expect(part.qty, 2.0);
      expect(part.edges, ['Кромка ПВХ 2мм дуб', 'Кромка ПВХ 0.4мм дуб']);
    });

    test('BazisMaterial deserialization', () {
      final mat = BazisMaterial.fromJson(const {
        'sync_id': 'MAT-LDSP-DUB-16',
        'name': 'ЛДСП Дуб Сонома 16мм',
        'code': 'L-16-DS',
        'owner': 'Панель',
        'kind': 'ОсновнойМатериал',
        'unit': 'м2',
        'qty': '2,352',
        'price': 4200.50,
      });

      expect(mat.syncId, 'MAT-LDSP-DUB-16');
      expect(mat.name, 'ЛДСП Дуб Сонома 16мм');
      expect(mat.code, 'L-16-DS');
      expect(mat.owner, 'Панель');
      expect(mat.kind, 'ОсновнойМатериал');
      expect(mat.unit, 'м2');
      expect(mat.qty, 2.352);
      expect(mat.price, 4200.5);
    });

    test('BazisOperation deserialization', () {
      final op = BazisOperation.fromJson(const {
        'sync_id': 'OP-CUT',
        'name': 'Раскрой',
        'qty': '6',
        'price': '350',
        'minutes': '12,5',
      });

      expect(op.syncId, 'OP-CUT');
      expect(op.name, 'Раскрой');
      expect(op.qty, 6.0);
      expect(op.price, 350.0);
      expect(op.minutes, 12.5);
    });

    test('BazisProduct and BazisInspectResult deserialization', () {
      final inspect = BazisInspectResult.fromJson(const {
        'message': {
          'products': [
            {
              'name': 'Кухонный гарнитур «Астана»',
              'article': 'KG-001',
              'order': 'SO-2026-0042',
              'qty': 1,
              'price': 780000.0,
              'parts': [
                {
                  'block': '1 / Нижняя секция',
                  'name': 'Дно',
                  'length': 600,
                  'width': 460,
                  'thickness': 16,
                  'qty': 1,
                },
              ],
              'materials': [
                {
                  'name': 'ЛДСП Белый',
                  'qty': 0.276,
                  'unit': 'м2',
                },
              ],
              'operations': [
                {
                  'name': 'Раскрой',
                  'minutes': 10,
                },
              ],
            },
          ],
          'totals': {
            'products': 1,
            'parts': 1,
            'materials': 1,
            'operations': 1,
          },
        },
      });

      expect(inspect.products.length, 1);
      final p = inspect.products.first;
      expect(p.name, 'Кухонный гарнитур «Астана»');
      expect(p.article, 'KG-001');
      expect(p.order, 'SO-2026-0042');
      expect(p.parts.length, 1);
      expect(p.parts.first.block, '1 / Нижняя секция');
      expect(p.materials.length, 1);
      expect(p.operations.length, 1);
      expect(inspect.totals.products, 1);
    });

    test('BazisImportResult and BazisImportedProduct deserialization', () {
      final result = BazisImportResult.fromJson(const {
        'message': {
          'company': 'KORKEM',
          'totals': {
            'products': 1,
            'parts': 1,
            'materials': 1,
            'operations': 1,
          },
          'products': [
            {
              'product': 'Кухонный гарнитур «Астана»',
              'item': 'KG-001',
              'bom': 'BOM-KG-001-001',
              'bom_status': 'created',
              'materials': ['БАЗИС-MAT-1'],
              'materials_without_quantity': ['Кромка без расчёта'],
              'operations': ['Раскрой'],
              'operations_awaiting_workstation': ['Кромление'],
              'sales_order': 'SO-2026-0042',
            },
          ],
        },
      });

      expect(result.company, 'KORKEM');
      expect(result.products.length, 1);
      final p = result.products.first;
      expect(p.product, 'Кухонный гарнитур «Астана»');
      expect(p.item, 'KG-001');
      expect(p.bom, 'BOM-KG-001-001');
      expect(p.bomStatus, 'created');
      expect(p.isUpdated, isFalse);
      expect(p.materials, ['БАЗИС-MAT-1']);
      expect(p.materialsWithoutQuantity, ['Кромка без расчёта']);
      expect(p.operations, ['Раскрой']);
      expect(p.operationsAwaitingWorkstation, ['Кромление']);
      expect(p.salesOrder, 'SO-2026-0042');
    });
  });

  group('BazisRepository', () {
    test('inspectSpecification uploads file and parses response', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.bazis.inspect',
        );
        expect(options.data, isA<FormData>());
        final form = options.data as FormData;
        expect(form.files.any((f) => f.key == 'file'), isTrue);

        return _json({
          'message': {
            'products': [
              {
                'name': 'Шкаф-купе',
                'article': 'SHK-01',
                'parts': <Map<String, dynamic>>[],
                'materials': <Map<String, dynamic>>[],
                'operations': <Map<String, dynamic>>[],
              },
            ],
            'totals': {
              'products': 1,
              'parts': 0,
              'materials': 0,
              'operations': 0,
            },
          },
        });
      });

      final repo = BazisRepository(FrappeClient(dio));
      final result = await repo.inspectSpecification(
        filename: 'export.xml',
        bytes: utf8.encode('<Проект><Изделие/></Проект>'),
      );

      expect(result.products.length, 1);
      expect(result.products.first.name, 'Шкаф-купе');
      expect(result.totals.products, 1);
    });

    test('inspectSpecification validates non-empty bytes', () async {
      final repo = BazisRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.inspectSpecification(filename: 'empty.xml', bytes: []),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      'inspectSpecification throws ServerFailure on unexpected response',
      () async {
        final dio = createDio((_) async => _json({'message': null}));
        final repo = BazisRepository(FrappeClient(dio));

        expect(
          () => repo.inspectSpecification(
            filename: 'test.xml',
            bytes: [1, 2, 3],
          ),
          throwsA(isA<ServerFailure>()),
        );
      },
    );

    test(
      'importSpecification uploads file with sales order and returns result',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.bazis.import_specification',
          );
          expect(options.data, isA<FormData>());
          final form = options.data as FormData;
          expect(form.files.any((f) => f.key == 'file'), isTrue);
          expect(
            form.fields.any(
              (f) => f.key == 'sales_order' && f.value == 'SO-2026-0042',
            ),
            isTrue,
          );

          return _json({
            'message': {
              'company': 'KORKEM',
              'totals': {
                'products': 1,
                'parts': 0,
                'materials': 1,
                'operations': 0,
              },
              'products': [
                {
                  'product': 'Шкаф-купе',
                  'item': 'SHK-01',
                  'bom': 'BOM-SHK-01-001',
                  'bom_status': 'updated',
                  'materials': ['БАЗИС-MAT-1'],
                  'materials_without_quantity': <String>[],
                  'operations': <String>[],
                  'operations_awaiting_workstation': <String>[],
                  'sales_order': 'SO-2026-0042',
                },
              ],
            },
          });
        });

        final repo = BazisRepository(FrappeClient(dio));
        final result = await repo.importSpecification(
          filename: 'export.xml',
          bytes: utf8.encode('<Проект/>'),
          salesOrder: 'SO-2026-0042',
        );

        expect(result.products.length, 1);
        expect(result.products.first.bomStatus, 'updated');
        expect(result.products.first.isUpdated, isTrue);
      },
    );

    test('importSpecification validates non-empty bytes', () async {
      final repo = BazisRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.importSpecification(filename: 'empty.xml', bytes: []),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
