import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';

final orderDesignRepositoryProvider = Provider<OrderDesignRepository>(
  (ref) => OrderDesignRepository(
    ref.watch(frappeClientProvider),
    ref.watch(dioProvider),
  ),
);

/// Communicates with Frappe/ERPNext for the Stage 5 Design lifecycle.
class OrderDesignRepository {
  const OrderDesignRepository(this._client, this._dio);

  static const assignMethod = 'korkem_manufacturing.api.design.assign';
  static const deliverMethod = 'korkem_manufacturing.api.design.deliver';

  final FrappeClient _client;
  final Dio _dio;

  /// Fetches the design task and attached drawings for one sales order.
  Future<OrderDesign> fetchDesign(String salesOrder) async {
    final tasks = await _client.getList(
      'CRM Task',
      FrappeQuery(
        fields: const [
          'name',
          'title',
          'assigned_to',
          'due_date',
          'status',
          'creation',
        ],
        filters: [
          const FrappeFilter.equals('reference_doctype', 'Sales Order'),
          FrappeFilter.equals('reference_docname', salesOrder),
        ],
        orderBy: 'creation desc',
        limitPageLength: 1,
      ),
    );

    final files = await _client.getList(
      'File',
      FrappeQuery(
        fields: const [
          'name',
          'file_name',
          'file_url',
          'file_size',
          'creation',
        ],
        filters: [
          const FrappeFilter.equals('attached_to_doctype', 'Sales Order'),
          FrappeFilter.equals('attached_to_name', salesOrder),
        ],
        orderBy: 'creation desc',
      ),
    );

    final task = tasks.firstOrNull;
    final status = task != null
        ? OrderDesignStatus.fromTaskStatus(task['status'] as String?)
        : OrderDesignStatus.notAssigned;

    DateTime? dueDate;
    if (task?['due_date'] is String) {
      dueDate = DateTime.tryParse(task!['due_date'] as String);
    }

    final attachments = files
        .map(OrderDesignAttachment.fromJson)
        .toList(growable: false);

    return OrderDesign(
      salesOrder: salesOrder,
      taskId: task?['name'] != null ? '${task!['name']}' : null,
      taskTitle: task?['title'] as String?,
      designer: task?['assigned_to'] as String?,
      dueDate: dueDate,
      status: status,
      attachments: attachments,
    );
  }

  /// Assigns a designer with a mandatory deadline to a sales order.
  Future<Map<String, dynamic>> assignDesign({
    required String salesOrder,
    required String designer,
    required String dueOn,
  }) async {
    final response = await _client.callMethod(
      assignMethod,
      params: {
        'sales_order': salesOrder,
        'designer': designer,
        'due_on': dueOn,
      },
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }

  /// Accepts/delivers design after checking drawings exist on the order.
  Future<Map<String, dynamic>> deliverDesign({
    required String salesOrder,
  }) async {
    final response = await _client.callMethod(
      deliverMethod,
      params: {'sales_order': salesOrder},
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }

  /// Attaches a drawing/specification file directly to the sales order.
  Future<OrderDesignAttachment> attachFile({
    required String salesOrder,
    required String fileName,
    String? fileUrl,
    String? content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/resource/File',
      data: <String, dynamic>{
        'file_name': fileName.trim(),
        'attached_to_doctype': 'Sales Order',
        'attached_to_name': salesOrder,
        'is_private': 1,
        if (fileUrl != null && fileUrl.trim().isNotEmpty)
          'file_url': fileUrl.trim(),
        'content': ?content,
      },
    );

    final raw = response.data?['data'] ?? response.data;
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return OrderDesignAttachment.fromJson(json);
  }
}
