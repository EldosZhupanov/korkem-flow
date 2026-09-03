import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(frappeClientProvider));
});

/// Data access for factory employee accounts, positions, and access.
class TeamRepository {
  TeamRepository(this._client);

  final FrappeClient _client;

  static const positionsEndpoint =
      'korkem_manufacturing.api.invitations.positions';
  static const inviteEndpoint = 'korkem_manufacturing.api.invitations.invite';
  static const changePositionEndpoint =
      'korkem_manufacturing.api.staff.change_position';
  static const deactivateEndpoint = 'korkem_manufacturing.api.staff.deactivate';
  static const reactivateEndpoint = 'korkem_manufacturing.api.staff.reactivate';

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
        .whereType<Map<Object?, Object?>>()
        .map((e) => PositionOption.fromJson(Map<String, dynamic>.from(e)))
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

  /// Сменить должность сотрудника (набор его прав).
  ///
  /// Вызывает POST korkem_manufacturing.api.staff.change_position.
  Future<ChangePositionResult> changePosition({
    required String email,
    required String position,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPosition = position.trim();
    if (cleanEmail.isEmpty) {
      throw const ValidationFailure('Email is required.');
    }
    if (cleanPosition.isEmpty) {
      throw const ValidationFailure('Position is required.');
    }

    final response = await _client.callMethod(
      changePositionEndpoint,
      post: true,
      params: {
        'email': cleanEmail,
        'position': cleanPosition,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to change position: unexpected response from server.',
      );
    }

    return ChangePositionResult.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Закрыть вход ушедшему сотруднику и завершить его активные сессии.
  ///
  /// Вызывает POST korkem_manufacturing.api.staff.deactivate.
  Future<DeactivateResult> deactivate({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const ValidationFailure('Email is required.');
    }

    final response = await _client.callMethod(
      deactivateEndpoint,
      post: true,
      params: {
        'email': cleanEmail,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to deactivate employee: unexpected response from server.',
      );
    }

    return DeactivateResult.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Вернуть доступ сотруднику.
  ///
  /// Вызывает POST korkem_manufacturing.api.staff.reactivate.
  Future<ReactivateResult> reactivate({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const ValidationFailure('Email is required.');
    }

    final response = await _client.callMethod(
      reactivateEndpoint,
      post: true,
      params: {
        'email': cleanEmail,
      },
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to reactivate employee: unexpected response from server.',
      );
    }

    return ReactivateResult.fromJson(Map<String, dynamic>.from(raw));
  }
}
