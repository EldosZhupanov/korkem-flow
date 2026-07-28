import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:meta/meta.dart';

/// A decision an AI agent is blocked on.
///
/// The most consequential record in the system: an agent has proposed an action
/// and stopped. Nothing downstream moves until a human resolves it, which is
/// why these outrank everything else on the dashboard.
@immutable
class PendingAction {
  const PendingAction({
    required this.id,
    required this.status,
    required this.agentSkill,
    this.entityType,
    this.entityName,
    this.actionClass,
    this.expiresAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  final String id;
  final PendingActionStatus status;

  /// What the agent was trying to do — `create_quote`, and so on.
  final String agentSkill;

  /// The record the action targets. A Dynamic Link, so the doctype travels
  /// with the name.
  final String? entityType;
  final String? entityName;

  final String? actionClass;
  final DateTime? expiresAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  /// Expiry is enforced server-side at approval time, not by this flag — the
  /// backend re-checks and refuses. This only decides what the UI offers, so a
  /// worker is not invited to tap a button that is certain to fail.
  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && now.isAfter(expiry);
  }

  bool get isPending => status == PendingActionStatus.pending;

  @override
  bool operator ==(Object other) => other is PendingAction && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Verified against the `Pending Action` doctype's Select options.
enum PendingActionStatus {
  pending('Pending', StatusIntent.warning),
  approved('Approved', StatusIntent.success),
  rejected('Rejected', StatusIntent.danger),
  expired('Expired', StatusIntent.neutral);

  const PendingActionStatus(this.wireValue, this.intent);

  final String wireValue;
  final StatusIntent intent;

  static PendingActionStatus fromWire(String? value) {
    for (final status in PendingActionStatus.values) {
      if (status.wireValue == value) return status;
    }
    // Unlike a CRM stage, these four are a fixed Select on a doctype this
    // project owns — an unknown value means the app is older than the backend.
    return PendingActionStatus.pending;
  }
}
