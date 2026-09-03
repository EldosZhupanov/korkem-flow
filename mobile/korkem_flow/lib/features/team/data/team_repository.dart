import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(frappeClientProvider));
});

/// Data access for factory employee accounts and invitations.
class TeamRepository {
  TeamRepository(this._client);

  final FrappeClient _client;

  static const positionsEndpoint =
      'korkem_manufacturing.api.invitations.positions';
  static const inviteEndpoint = 'korkem_manufacturing.api.invitations.invite';

  /// Должности и роли за ними — с сервера.
  ///
  /// Пустой ответ здесь не бывает: должности заданы в коде сервера, и если
  /// список не пришёл, значит сломался ответ, а не кончились должности. Тихо
  /// вернуть пустоту значило бы показать владельцу форму без единой должности
  /// и ни слова о том, почему.
  Future<List<PositionOption>> fetchPositions() async {
    final response = await _client.callMethod(positionsEndpoint);
    final rows = response['message'] ?? response['data'];

    if (rows is! List) {
      throw const ServerFailure(
        'Сервер не вернул список должностей. Приглашать вслепую нельзя: '
        'за должностью стоят права.',
      );
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PositionOption.fromJson)
        .toList(growable: false);
  }

  /// Fetches system users for the factory and resolves their assigned roles.
  Future<List<TeamMember>> fetchTeamMembers() async {
    final userRows = await _client.getList(
      'User',
      const FrappeQuery(
        fields: [
          'name',
          'email',
          'first_name',
          'full_name',
          'enabled',
          'user_type',
          'creation',
        ],
        filters: [
          FrappeFilter.equals('user_type', 'System User'),
        ],
        orderBy: 'creation desc',
        limitPageLength: 100,
      ),
    );

    final filteredUsers = userRows
        .where((row) {
          final name = '${row['name'] ?? ''}'.trim();
          return name != 'Administrator' && name != 'Guest';
        })
        .toList(growable: false);

    final rolesByUser = <String, List<String>>{};
    try {
      final roleRows = await _client.getList(
        'Has Role',
        const FrappeQuery(
          fields: ['parent', 'role'],
          filters: [FrappeFilter.equals('parenttype', 'User')],
          limitPageLength: 0,
        ),
      );
      for (final row in roleRows) {
        final parent = '${row['parent'] ?? ''}';
        final role = '${row['role'] ?? ''}';
        if (parent.isNotEmpty && role.isNotEmpty) {
          rolesByUser.putIfAbsent(parent, () => []).add(role);
        }
      }
    } on Object catch (_) {
      // If Has Role is not queried directly, we proceed with User roles
    }

    return filteredUsers
        .map(
          (row) => TeamMember.fromJson(
            row,
            roles: rolesByUser['${row['name'] ?? ''}'] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  /// Creates a company-bound employee with the specific position.
  Future<TeamInviteResult> inviteEmployee({
    required String email,
    required String position,
    String firstName = '',
  }) async {
    try {
      final response = await _client.callMethod(
        inviteEndpoint,
        post: true,
        params: {
          'email': email.trim().toLowerCase(),
          'first_name': firstName.trim(),
          'position': position.trim(),
        },
      );
      return TeamInviteResult.fromJson(response);
    } on PermissionFailure catch (e) {
      // Сервер отвечает 403, проверено живым запросом от сотрудника без прав.
      // Разбирать текст сообщения не нужно и опасно: отказ по смыслу «нельзя»
      // и отказ по смыслу «не та должность» приходят с разными кодами, а
      // совпадение слова в прозе однажды спутает их.
      throw TeamForbiddenException(e.message);
    }
  }
}
