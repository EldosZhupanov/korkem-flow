import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/enquiry_flow/data/enquiry_flow_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';

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

  group('EnquiryFlowRepository', () {
    test('fetches recent captures and single capture', () async {
      final dio = createDio((options) async {
        if (options.path.contains('/api/resource/Capture/CAP-001')) {
          return _json({
            'data': {
              'name': 'CAP-001',
              'spoken_text': 'Нужна кухня 3 метра',
              'customer_hint': 'Айгуль',
              'status': 'Recorded',
            },
          });
        }
        return _json({
          'data': [
            {
              'name': 'CAP-001',
              'spoken_text': 'Нужна кухня 3 метра',
              'customer_hint': 'Айгуль',
              'status': 'Recorded',
            },
          ],
        });
      });

      final client = FrappeClient(dio);
      final repo = EnquiryFlowRepository(client, dio);

      final list = await repo.fetchRecentCaptures();
      expect(list.length, 1);
      expect(list[0].id, 'CAP-001');

      final single = await repo.fetchCapture('CAP-001');
      expect(single.id, 'CAP-001');
      expect(single.customerHint, 'Айгуль');
    });

    test('convertCapture succeeds and returns ConvertResult', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.enquiry.convert',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['capture'], 'CAP-001');
        expect(data['customer_name'], 'Айгуль');

        return _json({
          'message': {
            'capture': 'CAP-001',
            'customer': 'CUST-001',
            'customer_created': true,
            'enquiry': 'OPP-001',
            'task': 'TASK-001',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = EnquiryFlowRepository(client, dio);

      final result = await repo.convertCapture(
        capture: 'CAP-001',
        customerName: 'Айгуль',
      );

      expect(result.capture, 'CAP-001');
      expect(result.customer, 'CUST-001');
      expect(result.enquiry, 'OPP-001');
      expect(result.customerCreated, isTrue);
    });

    test(
      'convertCapture handles 409 and throws AmbiguousCustomerException',
      () async {
        final dio = createDio((options) async {
          return _json({
            'message': {
              'status': 'ambiguous_customer',
              'message': 'More than one customer matches «Айгуль»',
              'candidates': [
                {
                  'name': 'CUST-001',
                  'customer_name': 'Айгуль Серикова',
                  'mobile_no': '+77011112233',
                },
                {
                  'name': 'CUST-002',
                  'customer_name': 'Айгуль Мухтарова',
                  'mobile_no': '+77023334455',
                },
              ],
            },
          }, statusCode: 409);
        });

        final client = FrappeClient(dio);
        final repo = EnquiryFlowRepository(client, dio);

        try {
          await repo.convertCapture(
            capture: 'CAP-001',
            customerName: 'Айгуль',
          );
          fail('Expected AmbiguousCustomerException');
        } on AmbiguousCustomerException catch (e) {
          expect(e.candidates.length, 2);
          expect(e.candidates[0].customerName, 'Айгуль Серикова');
          expect(e.candidates[1].customerName, 'Айгуль Мухтарова');
        }
      },
    );

    test('recordMeasurement sends dimensions and notes', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.measurement.record',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['enquiry'], 'OPP-001');
        expect(data['dimensions'], '3200x600');
        expect(data['address_line'], 'Абая 45');

        return _json({
          'message': {
            'enquiry': 'OPP-001',
            'address': 'ADDR-001',
            'task_closed': 'TASK-001',
            'measured_on': '2026-09-03',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = EnquiryFlowRepository(client, dio);

      final result = await repo.recordMeasurement(
        enquiry: 'OPP-001',
        dimensions: '3200x600',
        addressLine: 'Абая 45',
      );

      expect(result.enquiry, 'OPP-001');
      expect(result.address, 'ADDR-001');
      expect(result.measuredOn, '2026-09-03');
    });

    test('draftProposal sends item rows and validity', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.proposal.draft',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['enquiry'], 'OPP-001');
        expect(data['valid_days'], 14);

        return _json({
          'message': {
            'quotation': 'SAL-QTN-2026-0001',
            'status': 'drafted',
            'items': 1,
            'customer': 'CUST-001',
            'valid_till': '2026-09-17',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = EnquiryFlowRepository(client, dio);

      final result = await repo.draftProposal(
        enquiry: 'OPP-001',
        items: const [
          ProposalItem(
            itemCode: 'Кухня МДФ',
            rate: 450000,
            description: 'Кухня 3.2м глянец',
          ),
        ],
      );

      expect(result.quotation, 'SAL-QTN-2026-0001');
      expect(result.itemsCount, 1);
      expect(result.validTill, '2026-09-17');
    });

    test('acceptQuotation sends delivery date and creates order', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.acceptance.accept',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['quotation'], 'SAL-QTN-2026-0001');
        expect(data['deliver_on'], '2026-09-20');

        return _json({
          'message': {
            'quotation': 'SAL-QTN-2026-0001',
            'sales_order': 'SAL-ORD-2026-0001',
            'status': 'accepted',
            'total': 450000.0,
            'deliver_on': '2026-09-20',
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = EnquiryFlowRepository(client, dio);

      final result = await repo.acceptQuotation(
        quotation: 'SAL-QTN-2026-0001',
        deliverOn: '2026-09-20',
      );

      expect(result.salesOrder, 'SAL-ORD-2026-0001');
      expect(result.total, 450000.0);
      expect(result.deliverOn, '2026-09-20');
    });
  });
}
