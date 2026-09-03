import 'package:flutter/foundation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Pre-configured company positions mapped to stock ERPNext roles.
///
/// An arbitrary role list is never accepted from the client; positions map
/// strictly to backend-owned permission sets.
enum EmployeePosition {
  manager('manager'),
  warehouse('warehouse'),
  accountant('accountant'),
  shopFloor('shop_floor'),
  owner('owner');

  const EmployeePosition(this.id);

  final String id;

  /// Positions available in the invitation form.
  ///
  /// The owner is already present and cannot be invited from the form.
  static const List<EmployeePosition> selectable = [
    manager,
    warehouse,
    accountant,
    shopFloor,
  ];

  static EmployeePosition fromId(String? id) {
    if (id == null) return shopFloor;
    return switch (id.toLowerCase().trim()) {
      'manager' => manager,
      'warehouse' => warehouse,
      'accountant' => accountant,
      'shop_floor' || 'shopfloor' => shopFloor,
      'owner' => owner,
      _ => shopFloor,
    };
  }

  static EmployeePosition fromRoles(List<String> roles) {
    final set = roles.toSet();
    if (set.contains('System Manager') || set.contains('Korkem Admin')) {
      return owner;
    }
    if (set.contains('Manufacturing User') && set.contains('Stock User')) {
      return shopFloor;
    }
    if (set.contains('Sales Manager') || set.contains('Sales User')) {
      return manager;
    }
    if (set.contains('Accounts User') || set.contains('Accounts Manager')) {
      return accountant;
    }
    if (set.contains('Stock User') || set.contains('Stock Manager')) {
      return warehouse;
    }
    if (set.contains('Manufacturing User')) {
      return shopFloor;
    }
    return shopFloor;
  }

  String localizedName(AppLocalizations l10n) => switch (this) {
    manager => l10n.teamPositionManager,
    warehouse => l10n.teamPositionWarehouse,
    accountant => l10n.teamPositionAccountant,
    shopFloor => l10n.teamPositionShopFloor,
    owner => l10n.teamPositionOwner,
  };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
    manager => l10n.teamPositionManagerDesc,
    warehouse => l10n.teamPositionWarehouseDesc,
    accountant => l10n.teamPositionAccountantDesc,
    shopFloor => l10n.teamPositionShopFloorDesc,
    owner => l10n.teamPositionOwnerDesc,
  };
}

/// A person belonging to the current factory.
@immutable
class TeamMember {
  const TeamMember({
    required this.email,
    required this.firstName,
    required this.fullName,
    required this.position,
    required this.roles,
    required this.enabled,
    this.creation,
  });

  factory TeamMember.fromJson(
    Map<String, dynamic> json, {
    List<String> roles = const [],
    String? explicitPosition,
  }) {
    final email = '${json['email'] ?? json['name'] ?? ''}'.trim();
    final firstName = '${json['first_name'] ?? ''}'.trim();
    final fullName = '${json['full_name'] ?? firstName}'.trim();
    final enabled = json['enabled'] == 1 || json['enabled'] == true;
    final parsedRoles = [
      ...roles,
      if (json['roles'] is List)
        for (final r in json['roles'] as List)
          if (r is Map && r['role'] != null)
            '${r['role']}'
          else if (r is String)
            r,
    ];

    final position = explicitPosition != null
        ? EmployeePosition.fromId(explicitPosition)
        : EmployeePosition.fromRoles(parsedRoles);

    DateTime? creation;
    if (json['creation'] is String) {
      creation = DateTime.tryParse(json['creation'] as String);
    }

    return TeamMember(
      email: email,
      firstName: firstName.isNotEmpty ? firstName : email.split('@').first,
      fullName: fullName.isNotEmpty ? fullName : email,
      position: position,
      roles: parsedRoles,
      enabled: enabled,
      creation: creation,
    );
  }

  final String email;
  final String firstName;
  final String fullName;
  final EmployeePosition position;
  final List<String> roles;
  final bool enabled;
  final DateTime? creation;

  bool get isOwner =>
      position == EmployeePosition.owner ||
      roles.contains('System Manager') ||
      roles.contains('Korkem Admin');
}

/// A job position option retrieved from the server, mapping to backend-owned
/// roles.
@immutable
class PositionOption {
  const PositionOption({
    required this.position,
    required this.roles,
  });

  factory PositionOption.fromJson(Map<String, dynamic> json) {
    return PositionOption(
      position: '${json['position'] ?? ''}'.trim(),
      roles: [
        if (json['roles'] is List)
          for (final r in json['roles'] as List) '$r',
      ],
    );
  }

  final String position;
  final List<String> roles;

  String localizedName(AppLocalizations l10n) {
    final ep = EmployeePosition.fromId(position);
    if (position == 'owner' ||
        ep != EmployeePosition.shopFloor ||
        position == 'shop_floor' ||
        position == 'shopfloor') {
      return ep.localizedName(l10n);
    }
    return position;
  }

  String localizedDescription(AppLocalizations l10n) {
    final ep = EmployeePosition.fromId(position);
    if (position == 'owner' ||
        ep != EmployeePosition.shopFloor ||
        position == 'shop_floor' ||
        position == 'shopfloor') {
      return ep.localizedDescription(l10n);
    }
    return roles.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionOption &&
          runtimeType == other.runtimeType &&
          position == other.position;

  @override
  int get hashCode => position.hashCode;
}

/// The response payload when an employee is created or invited.
@immutable
class TeamInviteResult {
  const TeamInviteResult({
    required this.user,
    required this.company,
    required this.created,
    required this.position,
    required this.rolesAdded,
    this.passwordSet = false,
    this.nextStep,
    this.rawPosition,
  });

  factory TeamInviteResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    final rawPos = message['position'] as String?;
    return TeamInviteResult(
      user: '${message['user'] ?? ''}',
      company: message['company'] as String?,
      created: message['created'] == true || message['created'] == 1,
      position: EmployeePosition.fromId(rawPos),
      rawPosition: rawPos,
      rolesAdded: [
        if (message['roles_added'] is List)
          for (final r in message['roles_added'] as List) '$r',
      ],
      passwordSet:
          message['password_set'] == true || message['password_set'] == 1,
      nextStep: message['next_step'] as String?,
    );
  }

  final String user;
  final String? company;
  final bool created;
  final EmployeePosition position;
  final String? rawPosition;
  final List<String> rolesAdded;
  final bool passwordSet;
  final String? nextStep;
}

/// Refusal when a non-owner attempts to invite or manage employees.
class TeamForbiddenException implements Exception {
  const TeamForbiddenException([
    this.message =
        'Only the company owner can invite new employees and assign positions.',
  ]);

  final String message;

  @override
  String toString() => message;
}
