import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';

final orderInstallationRepositoryProvider =
    Provider<OrderInstallationRepository>(
      (ref) => OrderInstallationRepository(ref.watch(frappeClientProvider)),
    );

/// Communicates with Frappe/ERPNext for the Stage 10 Installation lifecycle.
class OrderInstallationRepository {
  const OrderInstallationRepository(this._client);

  static const scheduleMethod =
      'korkem_manufacturing.api.installation.schedule';
  static const completeMethod =
      'korkem_manufacturing.api.installation.complete';

  final FrappeClient _client;

  /// Fetches the installation task and crew notes for one sales order.
  Future<OrderInstallation> fetchInstallation(String salesOrder) async {
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
          const FrappeFilter.like('title', 'Монтаж по заказу%'),
        ],
        orderBy: 'creation desc',
        limitPageLength: 1,
      ),
    );

    final comments = await _client.getList(
      'Comment',
      FrappeQuery(
        fields: const ['name', 'content', 'creation'],
        filters: [
          const FrappeFilter.equals('reference_doctype', 'Sales Order'),
          FrappeFilter.equals('reference_name', salesOrder),
          const FrappeFilter.like('content', 'KORKEM: монтаж%'),
        ],
        orderBy: 'creation desc',
        limitPageLength: 1,
      ),
    );

    String? notes;
    if (comments.isNotEmpty) {
      final content = '${comments.first['content'] ?? ''}';
      notes = content
          .replaceFirst(RegExp(r'^KORKEM:\s*монтаж\s*[—–-]\s*'), '')
          .trim();
      if (notes.isEmpty) notes = null;
    }

    final task = tasks.firstOrNull;
    final status = task != null
        ? OrderInstallationStatus.fromTaskStatus(task['status'] as String?)
        : OrderInstallationStatus.notScheduled;

    DateTime? installDate;
    if (task?['due_date'] is String) {
      installDate = DateTime.tryParse(task!['due_date'] as String);
    }

    return OrderInstallation(
      salesOrder: salesOrder,
      taskId: task?['name'] != null ? '${task!['name']}' : null,
      installer: task?['assigned_to'] as String?,
      installDate: installDate,
      status: status,
      notes: notes,
    );
  }

  /// Schedules an installer/crew for a sales order on a specified date.
  Future<Map<String, dynamic>> scheduleInstallation({
    required String salesOrder,
    required String installer,
    required String installOn,
  }) async {
    final response = await _client.callMethod(
      scheduleMethod,
      params: {
        'sales_order': salesOrder,
        'installer': installer,
        'install_on': installOn,
      },
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }

  /// Completes the installation task with optional crew notes.
  Future<Map<String, dynamic>> completeInstallation({
    required String salesOrder,
    String? notes,
  }) async {
    final response = await _client.callMethod(
      completeMethod,
      params: {
        'sales_order': salesOrder,
        'notes': ?notes,
      },
      post: true,
    );
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }
}
