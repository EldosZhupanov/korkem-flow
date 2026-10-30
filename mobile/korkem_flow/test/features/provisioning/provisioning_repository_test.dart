import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/provisioning/data/provisioning_repository.dart';
import 'package:korkem_flow/features/provisioning/domain/provisioning_models.dart';

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

  group('ProvisioningRepository.checkStatus', () {
    test('returns unclaimed status with languages', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          'https://korkem.example.kz/api/method/korkem_manufacturing.api.provisioning.status',
        );
        return _json({
          'message': {
            'claimed': false,
            'languages': ['ru', 'kk', 'en'],
          },
        });
      });

      final repo = ProvisioningRepository(dio);
      final status = await repo.checkStatus('https://korkem.example.kz');

      expect(status.claimed, isFalse);
      expect(status.languages, ['ru', 'kk', 'en']);
    });

    test('returns claimed status', () async {
      final dio = createDio((options) async {
        return _json({
          'message': {
            'claimed': true,
            'languages': ['ru'],
          },
        });
      });

      final repo = ProvisioningRepository(dio);
      final status = await repo.checkStatus('https://korkem.example.kz');

      expect(status.claimed, isTrue);
      expect(status.languages, ['ru']);
    });

    test('falls back to claimed on 404 endpoint not found', () async {
      final dio = createDio((options) async {
        return _json({'message': 'Not Found'}, statusCode: 404);
      });

      final repo = ProvisioningRepository(dio);
      final status = await repo.checkStatus('https://korkem.example.kz');

      expect(status.claimed, isTrue);
    });
  });

  group('ProvisioningRepository.claim', () {
    test(
      'sends claim payload with trimmed launch code and returns ClaimResult',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            'https://korkem.example.kz/api/method/korkem_manufacturing.api.provisioning.claim',
          );
          final data = options.data as Map<String, dynamic>;
          expect(data['code'], 'ABCD1234EFGH5678');
          expect(data['company'], 'Korkem Mebel');
          expect(data['owner_email'], 'owner@korkem.kz');
          expect(data['owner_name'], 'Aidos Owner');
          expect(data['owner_password'], 'Secret123!');
          expect(data['language'], 'kk');
          return _json({
            'message': {
              'status': 'claimed',
              'company': 'Korkem Mebel',
              'owner': 'owner@korkem.kz',
              'roles': ['System Manager', 'Korkem Owner'],
            },
          });
        });

        final repo = ProvisioningRepository(dio);
        final result = await repo.claim(
          baseUrl: 'https://korkem.example.kz',
          code: 'ABCD 1234 EFGH 5678',
          company: '  Korkem Mebel  ',
          ownerEmail: '  owner@korkem.kz  ',
          ownerName: '  Aidos Owner  ',
          ownerPassword: 'Secret123!',
          language: 'kk',
        );

        expect(result.status, 'claimed');
        expect(result.company, 'Korkem Mebel');
        expect(result.owner, 'owner@korkem.kz');
        expect(result.roles, ['System Manager', 'Korkem Owner']);
      },
    );

    test(
      'throws ClaimAlreadyClaimedException on 409 already_claimed',
      () async {
        final dio = createDio((options) async {
          return _json({
            'message': {
              'status': 'already_claimed',
              'message': 'This node already has an owner.',
            },
          }, statusCode: 409);
        });

        final repo = ProvisioningRepository(dio);

        expect(
          () => repo.claim(
            baseUrl: 'https://korkem.example.kz',
            code: '1234567812345678',
            company: 'Korkem',
            ownerEmail: 'owner@korkem.kz',
            ownerName: 'Owner',
            ownerPassword: 'pass',
          ),
          throwsA(isA<ClaimAlreadyClaimedException>()),
        );
      },
    );

    test('throws ClaimCodeRefusedException on 403 code_refused', () async {
      final dio = createDio((options) async {
        return _json({
          'message': {
            'status': 'code_refused',
            'message': 'Wrong claim code.',
          },
        }, statusCode: 403);
      });

      final repo = ProvisioningRepository(dio);

      expect(
        () => repo.claim(
          baseUrl: 'https://korkem.example.kz',
          code: 'WRONGCODE',
          company: 'Korkem',
          ownerEmail: 'owner@korkem.kz',
          ownerName: 'Owner',
          ownerPassword: 'pass',
        ),
        throwsA(isA<ClaimCodeRefusedException>()),
      );
    });

    test('throws FrappeException on other server failure', () async {
      final dio = createDio((options) async {
        return _json({
          'exception': 'Internal Server Error',
        }, statusCode: 500);
      });

      final repo = ProvisioningRepository(dio);

      expect(
        () => repo.claim(
          baseUrl: 'https://korkem.example.kz',
          code: '1234567812345678',
          company: 'Korkem',
          ownerEmail: 'owner@korkem.kz',
          ownerName: 'Owner',
          ownerPassword: 'pass',
        ),
        throwsA(isA<FrappeException>()),
      );
    });
  });

  _unknownMeansClaimed();
}

void _unknownMeansClaimed() {
  group('Ответ, который мы не поняли, означает «узел занят»', () {
    // Направление этого умолчания — не вкусовщина. Репозиторий в трёх местах
    // считает непонятный ответ признаком занятого узла: при пустом адресе, при
    // 404 и при теле не того вида. Модель делала обратное — и это та же ошибка
    // с другой стороны: показать экран регистрации там, где хозяин уже есть,
    // значит предложить человеку создать компанию поверх существующей.
    test('поля claimed нет — считаем занятым, а не свободным', () {
      final status = ProvisioningStatus.fromJson(const {
        'languages': ['ru'],
      });

      expect(status.claimed, isTrue);
    });

    test('claimed: false остаётся false — узел действительно свободен', () {
      final status = ProvisioningStatus.fromJson(const {
        'claimed': false,
        'languages': ['ru'],
      });

      expect(status.claimed, isFalse);
    });

    test('claimed: true остаётся true', () {
      final status = ProvisioningStatus.fromJson(const {
        'claimed': true,
        'languages': ['ru'],
      });

      expect(status.claimed, isTrue);
    });
  });
}
