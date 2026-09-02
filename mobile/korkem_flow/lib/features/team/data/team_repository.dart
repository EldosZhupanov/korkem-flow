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

  static const inviteEndpoint =
      'korkem_manufacturing.services.invitations.invite_employee';

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
    required EmployeePosition position,
    String firstName = '',
  }) async {
    try {
      final response = await _client.callMethod(
        inviteEndpoint,
        post: true,
        params: {
          'email': email.trim().toLowerCase(),
          'first_name': firstName.trim(),
          'position': position.id,
        },
      );
      return TeamInviteResult.fromJson(response);
    } on FrappeException catch (e) {
      final msg = e.message.toLowerCase();
      if (e is PermissionFailure ||
          msg.contains('system manager') ||
          msg.contains('owner') ||
          msg.contains('permission') ||
          msg.contains('cannot change your own roles') ||
          msg.contains('only the owner')) {
        throw const TeamForbiddenException();
      }
      rethrow;
    }
  }
}
