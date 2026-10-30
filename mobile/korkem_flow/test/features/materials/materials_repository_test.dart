import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/materials/data/materials_repository.dart';
import 'package:korkem_flow/features/materials/domain/material_item.dart';
import 'package:mocktail/mocktail.dart';

class MockFrappeClient extends Mock implements FrappeClient {}

void main() {
  group('MaterialItem domain model', () {
    test('parses complete board record from server contract', () {
      final json = <String, dynamic>{
        'id': 'MAT-0001',
        'kind': 'board',
        'manufacturer': 'Egger',
        'decor_code': 'W1000 ST9',
        'name': 'Белый премиум',
        'thickness_mm': 16,
        'sheet_width_mm': 2800,
        'sheet_height_mm': 2070,
        'color_family': 'white',
        'active': true,
      };

      final item = MaterialItem.fromJson(json);

      expect(item.id, 'MAT-0001');
      expect(item.name, 'Белый премиум');
      expect(item.kind, MaterialKind.board);
      expect(item.isBoard, isTrue);
      expect(item.isEdge, isFalse);
      expect(item.manufacturer, 'Egger');
      expect(item.decorCode, 'W1000 ST9');
      expect(item.thicknessMm, 16.0);
      expect(item.sheetWidthMm, 2800);
      expect(item.sheetHeightMm, 2070);
      expect(item.colorFamily, 'white');
      expect(item.active, isTrue);
      expect(item.displayTitle, 'W1000 ST9 · Белый премиум');
    });

    test('parses edge band record distinguishing it from board', () {
      final json = <String, dynamic>{
        'id': 'MAT-0050',
        'kind': 'edge',
        'manufacturer': 'Rehau',
        'decor_code': 'W1000 ST9',
        'name': 'Кромка ПВХ Белый премиум',
        'thickness_mm': 2.0,
        'fits_thickness_mm': 18.0,
        'edge_width_mm': 23.0,
        'color_family': 'white',
        'active': true,
      };

      final item = MaterialItem.fromJson(json);

      expect(item.id, 'MAT-0050');
      expect(item.kind, MaterialKind.edge);
      expect(item.isEdge, isTrue);
      expect(item.isBoard, isFalse);
      expect(item.thicknessMm, 2.0);
      expect(item.fitsThicknessMm, 18.0);
      expect(item.edgeWidthMm, 23.0);
      expect(item.sheetWidthMm, isNull);
      expect(item.sheetHeightMm, isNull);
    });

    test('never invents missing data when server omits optional fields', () {
      // Contract: only id, name, and kind are required from server.
      final minimalJson = <String, dynamic>{
        'id': 'MAT-9999',
        'name': 'Простая плита',
        'kind': 'board',
      };

      final item = MaterialItem.fromJson(minimalJson);

      expect(item.id, 'MAT-9999');
      expect(item.name, 'Простая плита');
      expect(item.kind, MaterialKind.board);
      // Critical check: no plausible defaults like 16mm or 2800x2070
      expect(item.manufacturer, isNull);
      expect(item.decorCode, isNull);
      expect(item.thicknessMm, isNull);
      expect(item.sheetWidthMm, isNull);
      expect(item.sheetHeightMm, isNull);
      expect(item.colorFamily, isNull);
      expect(item.active, isTrue);

      // When decor code is missing, display title cleanly falls back to name
      expect(item.displayTitle, 'Простая плита');
    });

    test('tolerates string numbers and parses safely', () {
      final json = <String, dynamic>{
        'id': 'MAT-1234',
        'name': 'Дуб Сонома',
        'kind': 'board',
        'thickness_mm': '18.5',
        'sheet_width_mm': '2800',
        'sheet_height_mm': '2070',
        'active': 'true',
      };

      final item = MaterialItem.fromJson(json);

      expect(item.thicknessMm, 18.5);
      expect(item.sheetWidthMm, 2800);
      expect(item.sheetHeightMm, 2070);
      expect(item.active, isTrue);
    });

    test('trims whitespace and treats empty strings as null', () {
      final json = <String, dynamic>{
        'id': ' MAT-01 ',
        'name': ' Тест ',
        'kind': 'board',
        'manufacturer': '   ',
        'decor_code': '',
        'color_family': '  ',
      };

      final item = MaterialItem.fromJson(json);

      expect(item.id, 'MAT-01');
      expect(item.name, 'Тест');
      expect(item.manufacturer, isNull);
      expect(item.decorCode, isNull);
      expect(item.colorFamily, isNull);
      expect(item.displayTitle, 'Тест');
    });
  });

  group('MaterialsRepository', () {
    late MockFrappeClient client;
    late MaterialsRepository repository;

    setUp(() {
      client = MockFrappeClient();
      repository = MaterialsRepository(client);
    });

    test('fetchMaterials passes query params to FrappeClient', () async {
      when(
        () => client.callMethod(
          MaterialsRepository.endpoint,
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) async => {
          'message': {
            'materials': [
              {
                'id': 'MAT-0001',
                'kind': 'board',
                'manufacturer': 'Egger',
                'decor_code': 'W1000 ST9',
                'name': 'Белый премиум',
                'thickness_mm': 16,
                'sheet_width_mm': 2800,
                'sheet_height_mm': 2070,
                'color_family': 'white',
                'active': true,
              },
            ],
            'total': 1,
          },
        },
      );

      final result = await repository.fetchMaterials(
        limit: 50,
        offset: 10,
        query: 'W1000',
        thickness: 16,
        colorFamily: 'white',
        kind: 'board',
      );

      verify(
        () => client.callMethod(
          MaterialsRepository.endpoint,
          params: {
            'limit': 50,
            'offset': 10,
            'query': 'W1000',
            'thickness': 16,
            'color_family': 'white',
            'kind': 'board',
          },
        ),
      ).called(1);

      expect(result.total, 1);
      expect(result.materials, hasLength(1));
      expect(result.materials.first.decorCode, 'W1000 ST9');
    });

    test('handles list without message wrapper or empty response', () async {
      when(
        () => client.callMethod(
          MaterialsRepository.endpoint,
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) async => {'message': <dynamic>[]});

      final result = await repository.fetchMaterials();

      expect(result.total, 0);
      expect(result.materials, isEmpty);
    });
  });
}
