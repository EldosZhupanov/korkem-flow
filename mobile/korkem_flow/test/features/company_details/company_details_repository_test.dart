import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/company_details/data/company_details_repository.dart';
import 'package:korkem_flow/features/company_details/domain/company_details.dart';

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

  group('CompanyDetails', () {
    test('serializes and deserializes correctly', () {
      const details = CompanyDetails(
        company: 'eldos (Demo)',
        name: 'ТОО Көркем Жиһаз',
        bin: '123456789012',
        address: 'ул. Абая, 150',
        city: 'Алматы',
        phone: '+7 777 123 4567',
        email: 'info@korkem.kz',
        website: 'korkem.kz',
        bankName: 'АО Kaspi Bank',
        bankAccount: 'KZ123456789012345678',
        bik: 'CASPKZ2A',
      );

      final json = details.toJson();
      final fromJson = CompanyDetails.fromJson(json);

      expect(fromJson, details);
      expect(fromJson.company, 'eldos (Demo)');
      expect(fromJson.name, 'ТОО Көркем Жиһаз');
      expect(fromJson.bin, '123456789012');
      expect(fromJson.website, 'korkem.kz');
      expect(fromJson.bankAccount, 'KZ123456789012345678');
    });

    test('supports alternative json keys from ERPNext DocType', () {
      final fromJson = CompanyDetails.fromJson(const {
        'company': 'Korkem LTD',
        'company_name': 'Korkem Furniture',
        'tax_id': '987654321098',
        'address_line1': 'Dostyk 10',
        'city': 'Astana',
        'iban': 'KZ987654321098765432',
        'branch_code': 'KAZKKZ22',
      });

      expect(fromJson.company, 'Korkem LTD');
      expect(fromJson.name, 'Korkem Furniture');
      expect(fromJson.bin, '987654321098');
      expect(fromJson.address, 'Dostyk 10');
      expect(fromJson.city, 'Astana');
      expect(fromJson.bankAccount, 'KZ987654321098765432');
      expect(fromJson.bik, 'KAZKKZ22');
    });
  });

  group('CompanyDetailsRepository', () {
    test('fetches company details successfully via read endpoint', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.company_details.read',
        );
        return _json({
          'message': {
            'company': 'eldos (Demo)',
            'name': 'eldos',
            'bin': '123456789012',
            'city': 'Астана',
            'address': 'проспект Абая 15',
            'phone': '+7 777 123 4567',
            'email': 'info@korkem.kz',
            'website': 'korkem.kz',
            'bank_name': 'Kaspi Bank',
            'bank_account': 'KZ691234567890123456',
            'bik': 'CASPKZKA',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = CompanyDetailsRepository(client);

      final details = await repo.fetch();
      expect(details.company, 'eldos (Demo)');
      expect(details.name, 'eldos');
      expect(details.bin, '123456789012');
      expect(details.city, 'Астана');
      expect(details.address, 'проспект Абая 15');
      expect(details.website, 'korkem.kz');
      expect(details.bankAccount, 'KZ691234567890123456');
    });

    test('throws ServerFailure when server returns empty response', () async {
      final dio = createDio((options) async {
        return _json({'message': <String, dynamic>{}});
      });

      final client = FrappeClient(dio);
      final repo = CompanyDetailsRepository(client);

      expect(
        repo.fetch,
        throwsA(isA<ServerFailure>()),
      );
    });

    test('saves company details with payload via save endpoint', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.company_details.save',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['bin'], '123456789012');
        expect(data['bank_account'], 'KZ123456789012345678');
        expect(data.containsKey('name'), isFalse);

        return _json({
          'message': {
            'company': 'eldos (Demo)',
            'name': 'eldos',
            'bin': '123456789012',
            'city': 'Алматы',
            'address': 'ул. Абая, 150',
            'phone': '+7 777 123 4567',
            'email': 'info@korkem.kz',
            'website': 'korkem.kz',
            'bank_name': 'АО Kaspi Bank',
            'bank_account': 'KZ123456789012345678',
            'bik': 'CASPKZ2A',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = CompanyDetailsRepository(client);

      final saved = await repo.save(
        const CompanyDetails(
          bin: '123456789012',
          bankAccount: 'KZ123456789012345678',
        ),
      );

      expect(saved.name, 'eldos');
      expect(saved.bin, '123456789012');
      expect(saved.bankAccount, 'KZ123456789012345678');
    });

    test('неполная форма отправляется как есть и ничего не стирает', () async {
      // Владелец заводит реквизиты по частям: сегодня телефон, завтра, когда
      // откроет счёт, — банк. Пустое поле означает «пока не знаю», а не
      // «сотри», поэтому в запрос оно не попадает вовсе.
      late Map<String, dynamic> sent;
      final dio = createDio((options) async {
        sent = options.data as Map<String, dynamic>;
        return _json({
          'message': {
            'company': 'eldos (Demo)',
            'name': 'eldos',
            'bin': '123456789012',
            'phone': '+7 701 111 11 11',
          },
        });
      });
      final repo = CompanyDetailsRepository(FrappeClient(dio));

      final saved = await repo.save(
        const CompanyDetails(phone: '+7 701 111 11 11'),
      );

      expect(sent.keys.toList(), ['phone']);
      // БИН заведён раньше и вернулся нетронутым, хотя мы его не слали.
      expect(saved.bin, '123456789012');
    });

    test('сохранение без ответа — это отказ, а не «сохранено»', () async {
      // Вернуть здесь отправленное значило бы показать владельцу его же ввод
      // как записанный, хотя мы не знаем, что сервер с ним сделал.
      final dio = createDio((_) async => _json({'message': null}));
      final repo = CompanyDetailsRepository(FrappeClient(dio));

      await expectLater(
        repo.save(const CompanyDetails(phone: '+7 701 111 11 11')),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
