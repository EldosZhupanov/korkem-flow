import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/memory/data/memory_repository.dart';
import 'package:korkem_flow/features/memory/domain/memory_fact.dart';
import 'package:mocktail/mocktail.dart';

class _MockFrappeClient extends Mock implements FrappeClient {}

void main() {
  group('MemoryFact domain model', () {
    test('parses JSON with company scope correctly', () {
      final json = {
        'name': 'MEM-COMP-001',
        'text': 'ЛДСП считаем в квадратных метрах',
        'scope': 'company',
        'source_label': 'из разговора 2 сентября',
        'confirmed': true,
        'confirmed_at': '2026-09-02T14:30:00.000',
        'created_at': '2026-09-02T10:00:00.000',
      };

      final fact = MemoryFact.fromJson(json);

      expect(fact.id, 'MEM-COMP-001');
      expect(fact.text, 'ЛДСП считаем в квадратных метрах');
      expect(fact.scope, MemoryScope.company);
      expect(fact.sourceLabel, 'из разговора 2 сентября');
      expect(fact.isConfirmed, isTrue);
      expect(fact.confirmedAt, DateTime.parse('2026-09-02T14:30:00.000'));
      expect(fact.createdAt, DateTime.parse('2026-09-02T10:00:00.000'));
    });

    test('parses JSON with user scope and unconfirmed status', () {
      final json = {
        'id': 'MEM-USER-001',
        'fact': 'Основной язык — казахский',
        'scope': 'user',
        'source': 'указано вами',
        'is_confirmed': false,
      };

      final fact = MemoryFact.fromJson(json);

      expect(fact.id, 'MEM-USER-001');
      expect(fact.text, 'Основной язык — казахский');
      expect(fact.scope, MemoryScope.user);
      expect(fact.sourceLabel, 'указано вами');
      expect(fact.isConfirmed, isFalse);
      expect(fact.confirmedAt, isNull);
    });

    test('serializes to JSON accurately', () {
      const fact = MemoryFact(
        id: 'MEM-001',
        text: 'Кромку считаем в погонных метрах',
        scope: MemoryScope.company,
        sourceLabel: 'из настроек компании',
        isConfirmed: true,
      );

      final json = fact.toJson();

      expect(json['name'], 'MEM-001');
      expect(json['text'], 'Кромку считаем в погонных метрах');
      expect(json['scope'], 'company');
      expect(json['source_label'], 'из настроек компании');
      expect(json['confirmed'], isTrue);
    });
  });

  group('MemoryRepository', () {
    late _MockFrappeClient client;
    late MemoryRepository repository;

    setUp(() {
      client = _MockFrappeClient();
      repository = MemoryRepository(client);
    });

    test('fetchAll parses flat list from server response', () async {
      when(
        () => client.callMethod(MemoryRepository.listEndpoint),
      ).thenAnswer(
        (_) async => {
          'message': [
            {
              'name': 'MEM-1',
              'text': 'Станок ЧПУ настроен на 18мм',
              'scope': 'company',
              'source_label': 'из настроек',
              'confirmed': true,
            },
          ],
        },
      );

      final facts = await repository.fetchAll();

      expect(facts.length, 1);
      expect(facts.first.id, 'MEM-1');
      expect(facts.first.scope, MemoryScope.company);
      verify(() => client.callMethod(MemoryRepository.listEndpoint)).called(1);
    });

    test('fetchAll parses categorized map from server response', () async {
      when(
        () => client.callMethod(MemoryRepository.listEndpoint),
      ).thenAnswer(
        (_) async => {
          'message': {
            'company': [
              {
                'name': 'MEM-C1',
                'text': 'Цех работает с 9 до 18',
                'source_label': 'правило цеха',
                'confirmed': true,
              },
            ],
            'user': [
              {
                'name': 'MEM-U1',
                'text': 'Отвечает за закуп фурнитуры',
                'source_label': 'из разговора',
                'confirmed': false,
              },
            ],
          },
        },
      );

      final facts = await repository.fetchAll();

      expect(facts.length, 2);
      expect(facts[0].id, 'MEM-C1');
      expect(facts[0].scope, MemoryScope.company);
      expect(facts[1].id, 'MEM-U1');
      expect(facts[1].scope, MemoryScope.user);
    });

    test('updateFact sends name and updated text via post', () async {
      when(
        () => client.callMethod(
          MemoryRepository.updateEndpoint,
          post: true,
          params: {
            'name': 'MEM-C1',
            'text': 'Цех работает с 8 до 17',
          },
        ),
      ).thenAnswer(
        (_) async => {
          'message': {
            'name': 'MEM-C1',
            'text': 'Цех работает с 8 до 17',
            'scope': 'company',
            'source_label': 'указано вами',
            'confirmed': true,
          },
        },
      );

      final updated = await repository.updateFact(
        'MEM-C1',
        text: 'Цех работает с 8 до 17',
      );

      expect(updated.id, 'MEM-C1');
      expect(updated.text, 'Цех работает с 8 до 17');
      verify(
        () => client.callMethod(
          MemoryRepository.updateEndpoint,
          post: true,
          params: {
            'name': 'MEM-C1',
            'text': 'Цех работает с 8 до 17',
          },
        ),
      ).called(1);
    });

    test('confirmFact sends name to confirm endpoint via post', () async {
      when(
        () => client.callMethod(
          MemoryRepository.confirmEndpoint,
          post: true,
          params: {
            'name': 'MEM-U1',
          },
        ),
      ).thenAnswer(
        (_) async => {
          'message': {
            'name': 'MEM-U1',
            'text': 'Отвечает за закуп фурнитуры',
            'scope': 'user',
            'source_label': 'из разговора',
            'confirmed': true,
          },
        },
      );

      final confirmed = await repository.confirmFact('MEM-U1');

      expect(confirmed.id, 'MEM-U1');
      expect(confirmed.isConfirmed, isTrue);
      verify(
        () => client.callMethod(
          MemoryRepository.confirmEndpoint,
          post: true,
          params: {
            'name': 'MEM-U1',
          },
        ),
      ).called(1);
    });

    test('deleteFact sends name to delete endpoint via post', () async {
      when(
        () => client.callMethod(
          MemoryRepository.deleteEndpoint,
          post: true,
          params: {
            'name': 'MEM-DEL',
          },
        ),
      ).thenAnswer(
        (_) async => {'message': 'ok'},
      );

      await repository.deleteFact('MEM-DEL');

      verify(
        () => client.callMethod(
          MemoryRepository.deleteEndpoint,
          post: true,
          params: {
            'name': 'MEM-DEL',
          },
        ),
      ).called(1);
    });
  });
}
