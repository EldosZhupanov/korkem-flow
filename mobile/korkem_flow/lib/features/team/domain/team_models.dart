import 'package:flutter/foundation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Pre-configured company positions mapped to stock ERPNext roles.
///
/// An arbitrary role list is never accepted from the client; positions map
/// strictly to backend-owned permission sets.
enum EmployeePosition {
  manager('manager'),
  measurer('measurer'),
  designer('designer'),
  shopManager('shop_manager'),
  cutter('cutter'),
  edgeBanding('edge_banding'),
  cnc('cnc'),
  painter('painter'),
  assembler('assembler'),
  warehouse('warehouse'),
  installer('installer'),
  accountant('accountant'),
  shopFloor('shop_floor'),
  owner('owner');

  const EmployeePosition(this.id);

  final String id;

  /// Positions available in the invitation form.
  ///
  /// The owner is already present and cannot be invited from the form.
  /// Порядок — по ходу заказа: продажа, замер, конструктор, цех, склад,
  /// монтаж, деньги. Тот же порядок, что и на сервере.
  ///
  /// `shopFloor` здесь нет намеренно: он остался ради тех, кого пригласили до
  /// 4 сентября 2026, и показывать его в форме — значит предлагать новую
  /// должность «рабочий цеха» вместо конкретного станка.
  static const List<EmployeePosition> selectable = [
    manager,
    measurer,
    designer,
    shopManager,
    cutter,
    edgeBanding,
    cnc,
    painter,
    assembler,
    warehouse,
    installer,
    accountant,
  ];

  static EmployeePosition fromId(String? id) {
    if (id == null) return shopFloor;
    return switch (id.toLowerCase().trim()) {
      'manager' => manager,
      'warehouse' => warehouse,
      'accountant' => accountant,
      'measurer' => measurer,
      'designer' => designer,
      'shop_manager' || 'shopmanager' => shopManager,
      'cutter' => cutter,
      'edge_banding' || 'edgebanding' => edgeBanding,
      'cnc' => cnc,
      'painter' => painter,
      'assembler' => assembler,
      'installer' => installer,
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
    measurer => l10n.teamPositionMeasurer,
    designer => l10n.teamPositionDesigner,
    shopManager => l10n.teamPositionShopManager,
    cutter => l10n.teamPositionCutter,
    edgeBanding => l10n.teamPositionEdgeBanding,
    cnc => l10n.teamPositionCnc,
    painter => l10n.teamPositionPainter,
    assembler => l10n.teamPositionAssembler,
    warehouse => l10n.teamPositionWarehouse,
    installer => l10n.teamPositionInstaller,
    accountant => l10n.teamPositionAccountant,
    shopFloor => l10n.teamPositionShopFloor,
    owner => l10n.teamPositionOwner,
  };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
    manager => l10n.teamPositionManagerDesc,
    measurer => l10n.teamPositionMeasurerDesc,
    designer => l10n.teamPositionDesignerDesc,
    shopManager => l10n.teamPositionShopManagerDesc,
    cutter => l10n.teamPositionCutterDesc,
    edgeBanding => l10n.teamPositionEdgeBandingDesc,
    cnc => l10n.teamPositionCncDesc,
    painter => l10n.teamPositionPainterDesc,
    assembler => l10n.teamPositionAssemblerDesc,
    warehouse => l10n.teamPositionWarehouseDesc,
    installer => l10n.teamPositionInstallerDesc,
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

  TeamMember copyWith({
    String? email,
    String? firstName,
    String? fullName,
    EmployeePosition? position,
    List<String>? roles,
    bool? enabled,
    DateTime? creation,
  }) {
    return TeamMember(
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      roles: roles ?? this.roles,
      enabled: enabled ?? this.enabled,
      creation: creation ?? this.creation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          firstName == other.firstName &&
          fullName == other.fullName &&
          position == other.position &&
          listEquals(roles, other.roles) &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    email,
    firstName,
    fullName,
    position,
    Object.hashAll(roles),
    enabled,
  );
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

/// Result of changing an employee's position.
@immutable
class ChangePositionResult {
  const ChangePositionResult({
    required this.user,
    required this.position,
    required this.roles,
    required this.enabled,
  });

  factory ChangePositionResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    return ChangePositionResult(
      user: '${message['user'] ?? ''}',
      position: '${message['position'] ?? ''}',
      roles: [
        if (message['roles'] is List)
          for (final r in message['roles'] as List) '$r',
      ],
      enabled: message['enabled'] == true || message['enabled'] == 1,
    );
  }

  final String user;
  final String position;
  final List<String> roles;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangePositionResult &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          position == other.position &&
          listEquals(roles, other.roles) &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      Object.hash(user, position, Object.hashAll(roles), enabled);
}

/// Result of deactivating an employee account.
@immutable
class DeactivateResult {
  const DeactivateResult({
    required this.user,
    required this.enabled,
    required this.sessionsClosed,
    required this.status,
  });

  factory DeactivateResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    return DeactivateResult(
      user: '${message['user'] ?? ''}',
      enabled: message['enabled'] == true || message['enabled'] == 1,
      sessionsClosed: switch (message['sessions_closed']) {
        final num n => n.toInt(),
        final String s when int.tryParse(s) != null => int.parse(s),
        _ => 0,
      },
      status: '${message['status'] ?? ''}',
    );
  }

  final String user;
  final bool enabled;
  final int sessionsClosed;
  final String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeactivateResult &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          enabled == other.enabled &&
          sessionsClosed == other.sessionsClosed &&
          status == other.status;

  @override
  int get hashCode => Object.hash(user, enabled, sessionsClosed, status);
}

/// Result of reactivating an employee account.
@immutable
class ReactivateResult {
  const ReactivateResult({
    required this.user,
    required this.enabled,
    required this.status,
  });

  factory ReactivateResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    return ReactivateResult(
      user: '${message['user'] ?? ''}',
      enabled: message['enabled'] == true || message['enabled'] == 1,
      status: '${message['status'] ?? ''}',
    );
  }

  final String user;
  final bool enabled;
  final String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactivateResult &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          enabled == other.enabled &&
          status == other.status;

  @override
  int get hashCode => Object.hash(user, enabled, status);
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
