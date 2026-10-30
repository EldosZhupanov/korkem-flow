import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/hardware/data/hardware_repository.dart';
import 'package:korkem_flow/features/hardware/domain/hardware_item.dart';
import 'package:mocktail/mocktail.dart';

class MockFrappeClient extends Mock implements FrappeClient {}

void main() {
  group('HardwareItem domain model', () {
    test('parses complete hinge record from server contract', () {
      final json = <String, dynamic>{
        'id': 'HW-0001',
        'hardware_type': 'hinge',
        'brand': 'Boyard',
        'model': 'H301',
        'name': 'Петля накладная 110°',
        'overlay': 'full',
        'cup_diameter_mm': 35,
        'cup_depth_mm': 11.3,
        'mounting_system': 'german',
        'opening_angle_deg': 110,
        'soft_close': true,
        'length_mm': null,
        'load_kg': null,
        'colour': 'никель',
        'active': true,
      };

      final item = HardwareItem.fromJson(json);

      expect(item.id, 'HW-0001');
      expect(item.hardwareType, HardwareType.hinge);
      expect(item.isHinge, isTrue);
      expect(item.isRunner, isFalse);
      expect(item.isHandle, isFalse);
      expect(item.brand, 'Boyard');
      expect(item.model, 'H301');
      expect(item.name, 'Петля накладная 110°');
      expect(item.overlay, HingeOverlay.full);
      expect(item.cupDiameterMm, 35.0);
      expect(item.cupDepthMm, 11.3);
      expect(item.mountingSystem, MountingSystem.german);
      expect(item.openingAngleDeg, 110.0);
      expect(item.softClose, isTrue);
      expect(item.lengthMm, isNull);
      expect(item.loadKg, isNull);
      expect(item.colour, 'никель');
      expect(item.active, isTrue);
      expect(item.displayTitle, 'Boyard H301 · Петля накладная 110°');
    });

    test('parses runner slide record with length and load', () {
      final json = <String, dynamic>{
        'id': 'HW-0020',
        'hardware_type': 'runner',
        'brand': 'Hettich',
        'model': 'Quadro V6',
        'name': 'Направляющие скрытого монтажа',
        'length_mm': 450.0,
        'load_kg': 30.0,
        'soft_close': true,
        'colour': 'сталь',
      };

      final item = HardwareItem.fromJson(json);

      expect(item.id, 'HW-0020');
      expect(item.hardwareType, HardwareType.runner);
      expect(item.isRunner, isTrue);
      expect(item.isHinge, isFalse);
      expect(item.brand, 'Hettich');
      expect(item.model, 'Quadro V6');
      expect(item.lengthMm, 450.0);
      expect(item.loadKg, 30.0);
      expect(item.softClose, isTrue);
      expect(item.colour, 'сталь');
      expect(item.overlay, isNull);
      expect(item.cupDiameterMm, isNull);
    });

    test('keeps handle hole spacing separate from runner length', () {
      final json = <String, dynamic>{
        'id': 'HW-0050',
        'hardware_type': 'handle',
        'brand': 'GTV',
        'model': 'UA-HEXA',
        'name': 'Ручка профильная',
        'hole_spacing_mm': 128,
        'colour': 'черный матовый',
      };

      final item = HardwareItem.fromJson(json);

      expect(item.id, 'HW-0050');
      expect(item.hardwareType, HardwareType.handle);
      expect(item.isHandle, isTrue);
      expect(item.lengthMm, isNull);
      expect(item.colour, 'черный матовый');
      expect(item.toJson()['hole_spacing_mm'], 128.0);
    });

    test('never invents missing data when server omits optional fields', () {
      // Contract: only id, name, and hardware_type are guaranteed.
      final minimalJson = <String, dynamic>{
        'id': 'HW-9999',
        'hardware_type': 'hinge',
        'name': 'Базовая петля',
      };

      final item = HardwareItem.fromJson(minimalJson);

      expect(item.id, 'HW-9999');
      expect(item.name, 'Базовая петля');
      expect(item.hardwareType, HardwareType.hinge);
      // Invariant: no plausible defaults like 35mm, 110 deg, or full overlay
      expect(item.brand, isNull);
      expect(item.model, isNull);
      expect(item.overlay, isNull);
      expect(item.cupDiameterMm, isNull);
      expect(item.cupDepthMm, isNull);
      expect(item.mountingSystem, isNull);
      expect(item.openingAngleDeg, isNull);
      expect(item.softClose, isNull);
      expect(item.lengthMm, isNull);
      expect(item.loadKg, isNull);
      expect(item.holeSpacingMm, isNull);
      expect(item.colour, isNull);
      expect(item.active, isTrue);

      // Falls back to name when brand and model are absent
      expect(item.displayTitle, 'Базовая петля');
    });

    test('tolerates string numbers and parses safely', () {
      final json = <String, dynamic>{
        'id': 'HW-1234',
        'hardware_type': 'hinge',
        'name': 'Петля Boyard',
        'cup_diameter_mm': '35.0',
        'cup_depth_mm': '11.3',
        'opening_angle_deg': '110',
        'length_mm': '450',
        'load_kg': '30.5',
        'hole_spacing_mm': '128',
        'soft_close': 'true',
        'active': '1',
      };

      final item = HardwareItem.fromJson(json);

      expect(item.cupDiameterMm, 35.0);
      expect(item.cupDepthMm, 11.3);
      expect(item.openingAngleDeg, 110.0);
      expect(item.lengthMm, 450.0);
      expect(item.loadKg, 30.5);
      expect(item.holeSpacingMm, 128.0);
      expect(item.softClose, isTrue);
      expect(item.active, isTrue);
    });

    test('parses explicit soft-close values and keeps unknown values null', () {
      HardwareItem itemWith(String? value) => HardwareItem.fromJson({
        'id': 'HW-SOFT-CLOSE',
        'hardware_type': 'hinge',
        'name': 'Петля',
        'soft_close': value,
      });

      expect(itemWith('yes').softClose, isTrue);
      expect(itemWith('true').softClose, isTrue);
      expect(itemWith('1').softClose, isTrue);
      expect(itemWith('no').softClose, isFalse);
      expect(itemWith('false').softClose, isFalse);
      expect(itemWith('0').softClose, isFalse);
      expect(itemWith('').softClose, isNull);
      expect(itemWith(null).softClose, isNull);
    });

    test('trims whitespace and treats empty strings as null', () {
      final json = <String, dynamic>{
        'id': ' HW-01 ',
        'name': ' Тест ',
        'hardware_type': 'hinge',
        'brand': '   ',
        'model': '',
        'colour': '  ',
      };

      final item = HardwareItem.fromJson(json);

      expect(item.id, 'HW-01');
      expect(item.name, 'Тест');
      expect(item.brand, isNull);
      expect(item.model, isNull);
      expect(item.colour, isNull);
      expect(item.displayTitle, 'Тест');
    });

    test('correctly parses HingeOverlay enums', () {
      expect(HingeOverlay.fromString('full'), HingeOverlay.full);
      expect(HingeOverlay.fromString('half'), HingeOverlay.half);
      expect(HingeOverlay.fromString('inset'), HingeOverlay.inset);
      expect(HingeOverlay.fromString('unknown'), isNull);
      expect(HingeOverlay.fromString(null), isNull);
    });

    test('correctly parses MountingSystem enums', () {
      expect(MountingSystem.fromString('austrian'), MountingSystem.austrian);
      expect(MountingSystem.fromString('italian'), MountingSystem.italian);
      expect(MountingSystem.fromString('german'), MountingSystem.german);
      expect(MountingSystem.fromString('mini'), MountingSystem.mini);
      expect(MountingSystem.fromString('other'), isNull);
    });
  });

  group('HardwareRepository', () {
    late MockFrappeClient client;
    late HardwareRepository repository;

    setUp(() {
      client = MockFrappeClient();
      repository = HardwareRepository(client);
    });

    test('fetchHardware passes query params to FrappeClient', () async {
      when(
        () => client.callMethod(
          HardwareRepository.endpoint,
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) async => {
          'message': {
            'hardware': [
              {
                'id': 'HW-0001',
                'hardware_type': 'hinge',
                'brand': 'Boyard',
                'model': 'H301',
                'name': 'Петля накладная 110°',
                'overlay': 'full',
                'cup_diameter_mm': 35,
                'cup_depth_mm': 11.3,
                'mounting_system': 'german',
                'opening_angle_deg': 110,
                'soft_close': true,
              },
            ],
            'total': 1,
          },
        },
      );

      final result = await repository.fetchHardware(
        limit: 50,
        offset: 10,
        query: 'H301',
        hardwareType: 'hinge',
        overlay: 'full',
      );

      verify(
        () => client.callMethod(
          HardwareRepository.endpoint,
          params: {
            'limit': 50,
            'start': 10,
            'query': 'H301',
            'hardware_type': 'hinge',
            'overlay': 'full',
          },
        ),
      ).called(1);

      expect(result.total, 1);
      expect(result.hardware, hasLength(1));
      expect(result.hardware.first.model, 'H301');
      expect(result.hardware.first.overlay, HingeOverlay.full);
    });

    test('handles list without message wrapper or empty response', () async {
      when(
        () => client.callMethod(
          HardwareRepository.endpoint,
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) async => {'message': <dynamic>[]});

      final result = await repository.fetchHardware();

      expect(result.total, 0);
      expect(result.hardware, isEmpty);
    });
  });
}
