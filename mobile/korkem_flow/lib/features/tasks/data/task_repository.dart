import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/tasks/data/task_dto.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';

/// Reads and completes `CRM Task`.
class TaskRepository {
  const TaskRepository(this._client);

  static const doctype = 'CRM Task';

  final FrappeClient _client;

  Future<List<WorkTask>> fetchPage({
    required int pageSize,
    int offset = 0,
    bool openOnly = true,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: TaskDto.listFields,
        filters: [
          if (openOnly)
            const FrappeFilter.isIn('status', [
              'Backlog',
              'Todo',
              'In Progress',
            ]),
        ],
        // Nulls sort last in MariaDB, so undated tasks fall below dated ones —
        // which is what a worker wants: deadlines first.
        orderBy: 'due_date asc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(TaskDto.fromJson).toList(growable: false);
  }

  /// Marks a shop-floor task finished.
  ///
  /// Uses the one verified custom endpoint. `task` is sent as an **int**:
  /// Frappe type-checks whitelisted method arguments at runtime and a String
  /// here is rejected outright.
  Future<void> complete(int id, {String? notes}) async {
    await _client.callMethod(
      'korkem_manufacturing.shop_floor.complete_task',
      post: true,
      params: <String, dynamic>{'task': id, 'notes': ?notes},
    );
  }
}
