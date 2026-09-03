import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
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
  static const membersEndpoint = 'korkem_manufacturing.api.staff.members';
  static const canInviteEndpoint = 'korkem_manufacturing.api.staff.can_invite';
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

  /// Кто в компании и кем работает — по ответу сервера, а не по догадке.
  ///
  /// Раньше здесь было два запроса: список людей и отдельно их роли из
  /// `Has Role`. Вторая — детская таблица, и Frappe закрывает её даже от
  /// владельца компании. Отказ ловился пустым `catch`, роли приходили пустыми,
  /// должность выводилась из пустоты — и владелец видел себя «рабочим цеха», а
  /// кнопка «Пригласить сотрудника» не появлялась вовсе.
  ///
  /// Должность считает сервер: он и раздаёт роли, и знает, кто владелец.
  Future<List<TeamMember>> fetchTeamMembers() async {
    final response = await _client.callMethod(membersEndpoint);
    final rows = response['message'] ?? response['data'];

    if (rows is! List) {
      throw const ServerFailure(
        'Сервер не вернул список сотрудников. Показывать пустую команду там, '
        'где люди есть, — хуже, чем сказать об этом.',
      );
    }

    return rows
        .whereType<Map<Object?, Object?>>()
        .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Может ли вошедший звать людей. Ответ сервера, одним словом.
  Future<bool> canInvite() async {
    final response = await _client.callMethod(canInviteEndpoint);
    final value = response['message'] ?? response['data'];
    return value == true || value == 1;
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
