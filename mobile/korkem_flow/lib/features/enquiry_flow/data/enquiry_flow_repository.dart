import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';

final enquiryFlowRepositoryProvider = Provider<EnquiryFlowRepository>((ref) {
  return EnquiryFlowRepository(
    ref.watch(frappeClientProvider),
    ref.watch(dioProvider),
  );
});

/// Data access for the end-to-end request-to-order pipeline.
class EnquiryFlowRepository {
  EnquiryFlowRepository(this._client, this._dio);

  final FrappeClient _client;
  final Dio _dio;

  static const convertEndpoint = 'korkem_manufacturing.api.enquiry.convert';
  static const candidatesEndpoint =
      'korkem_manufacturing.api.enquiry.customer_candidates';
  static const measurementEndpoint =
      'korkem_manufacturing.api.measurement.record';
  static const proposalEndpoint = 'korkem_manufacturing.api.proposal.draft';
  static const acceptEndpoint = 'korkem_manufacturing.api.acceptance.accept';

  Future<List<CaptureSummary>> fetchRecentCaptures({int limit = 20}) async {
    final rows = await _client.getList(
      'Capture',
      FrappeQuery(
        fields: const [
          'name',
          'spoken_text',
          'customer_hint',
          'product_hint',
          'due_hint',
          'status',
          'enquiry',
          'task',
          'creation',
        ],
        orderBy: 'creation desc',
        limitPageLength: limit,
      ),
    );
    return rows.map(CaptureSummary.fromJson).toList(growable: false);
  }

  Future<CaptureSummary> fetchCapture(String id) async {
    final doc = await _client.getDoc('Capture', id);
    return CaptureSummary.fromJson(doc);
  }

  Future<Map<String, dynamic>> fetchEnquiry(String id) async {
    return _client.getDoc('Opportunity', id);
  }

  Future<MeasurementResult?> fetchMeasurementForEnquiry(
    String enquiryId,
  ) async {
    final rows = await _client.getList(
      'Comment',
      FrappeQuery(
        fields: const ['name', 'content', 'creation'],
        filters: [
          const FrappeFilter.equals('reference_doctype', 'Opportunity'),
          FrappeFilter.equals('reference_name', enquiryId),
          const FrappeFilter.equals('comment_type', 'Info'),
        ],
        orderBy: 'creation desc',
      ),
    );
    for (final row in rows) {
      final content = '${row['content'] ?? ''}';
      if (content.contains('KORKEM: замер')) {
        return MeasurementResult(
          enquiry: enquiryId,
          measuredOn: '${row['creation'] ?? ''}',
          dimensions: content,
        );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchQuotationForEnquiry(
    String enquiryId,
  ) async {
    final rows = await _client.getList(
      'Quotation',
      FrappeQuery(
        fields: const [
          'name',
          'status',
          'docstatus',
          'valid_till',
          'net_total',
          'grand_total',
          'creation',
        ],
        filters: [FrappeFilter.equals('opportunity', enquiryId)],
        orderBy: 'creation desc',
        limitPageLength: 1,
      ),
    );
    return rows.firstOrNull;
  }

  Future<Map<String, dynamic>?> fetchOrderForQuotation(
    String quotationId,
  ) async {
    final rows = await _client.getList(
      'Sales Order Item',
      FrappeQuery(
        fields: const ['parent', 'delivery_date'],
        filters: [
          FrappeFilter.equals('prevdoc_docname', quotationId),
          const FrappeFilter.equals('parenttype', 'Sales Order'),
        ],
        limitPageLength: 1,
      ),
    );
    return rows.firstOrNull;
  }

  Future<ConvertResult> convertCapture({
    required String capture,
    String? customer,
    String? customerName,
    String? assignMeasurer,
    String? measureOn,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/method/$convertEndpoint',
        data: {
          'capture': capture,
          if (customer != null && customer.isNotEmpty) 'customer': customer,
          if (customerName != null && customerName.isNotEmpty)
            'customer_name': customerName,
          if (assignMeasurer != null && assignMeasurer.isNotEmpty)
            'assign_measurer': assignMeasurer,
          if (measureOn != null && measureOn.isNotEmpty)
            'measure_on': measureOn,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return ConvertResult.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final map = data is Map<String, dynamic>
            ? (data['message'] is Map<String, dynamic>
                  ? data['message'] as Map<String, dynamic>
                  : data)
            : const <String, dynamic>{};
        if (map['status'] == 'ambiguous_customer' ||
            map['candidates'] is List) {
          final candidatesList = map['candidates'] as List? ?? const [];
          final candidates = [
            for (final c in candidatesList)
              if (c is Map<String, dynamic>) CustomerCandidate.fromJson(c),
          ];
          throw AmbiguousCustomerException(
            message: '${map['message'] ?? 'Ambiguous customer'}',
            candidates: candidates,
          );
        }
      }
      throw FrappeException.fromDio(e);
    }
  }

  Future<List<CustomerCandidate>> fetchCustomerCandidates(
    String nameSaid,
  ) async {
    final response = await _client.callMethod(
      candidatesEndpoint,
      params: {'name_said': nameSaid},
    );
    final message = response['message'] is Map<String, dynamic>
        ? response['message'] as Map<String, dynamic>
        : response;
    final list = message['candidates'] as List? ?? const [];
    return [
      for (final c in list)
        if (c is Map<String, dynamic>) CustomerCandidate.fromJson(c),
    ];
  }

  Future<MeasurementResult> recordMeasurement({
    required String enquiry,
    String? dimensions,
    String? notes,
    String? addressLine,
    String? city,
    String? measuredOn,
    List<String> photos = const [],
  }) async {
    final response = await _client.callMethod(
      measurementEndpoint,
      post: true,
      params: {
        'enquiry': enquiry,
        if (dimensions != null && dimensions.trim().isNotEmpty)
          'dimensions': dimensions.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (addressLine != null && addressLine.trim().isNotEmpty)
          'address_line': addressLine.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (measuredOn != null && measuredOn.trim().isNotEmpty)
          'measured_on': measuredOn.trim(),
      },
    );
    return MeasurementResult.fromJson(
      response,
      dimensions: dimensions,
      notes: notes,
      photos: photos,
    );
  }

  Future<ProposalResult> draftProposal({
    required String enquiry,
    required List<ProposalItem> items,
    int validDays = 14,
  }) async {
    final response = await _client.callMethod(
      proposalEndpoint,
      post: true,
      params: {
        'enquiry': enquiry,
        'items': jsonEncode([for (final item in items) item.toJson()]),
        'valid_days': validDays,
      },
    );
    return ProposalResult.fromJson(response, items: items);
  }

  Future<OrderAcceptResult> acceptQuotation({
    required String quotation,
    required String deliverOn,
  }) async {
    final response = await _client.callMethod(
      acceptEndpoint,
      post: true,
      params: {
        'quotation': quotation,
        'deliver_on': deliverOn.trim(),
      },
    );
    return OrderAcceptResult.fromJson(response);
  }
}
