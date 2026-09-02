import 'package:meta/meta.dart';

/// The setup status of a node, returned before authentication exists.
@immutable
class ProvisioningStatus {
  const ProvisioningStatus({
    required this.claimed,
    required this.languages,
  });

  factory ProvisioningStatus.fromJson(Map<String, dynamic> json) {
    final rawLangs = json['languages'] as List? ?? const [];
    final langs = rawLangs.map((e) => e.toString()).toList();
    return ProvisioningStatus(
      claimed: json['claimed'] as bool? ?? false,
      languages: langs.isEmpty ? const ['ru', 'kk', 'en'] : langs,
    );
  }

  final bool claimed;
  final List<String> languages;
}

/// The result of claiming a node and creating its first company and owner.
@immutable
class ClaimResult {
  const ClaimResult({
    required this.status,
    required this.company,
    required this.owner,
    required this.roles,
  });

  factory ClaimResult.fromJson(Map<String, dynamic> json) => ClaimResult(
    status: json['status'] as String? ?? 'claimed',
    company: json['company'] as String? ?? '',
    owner: json['owner'] as String? ?? '',
    roles: (json['roles'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  final String status;
  final String company;
  final String owner;
  final List<String> roles;
}

/// Base class for business refusals when claiming a node.
sealed class ClaimRefusalException implements Exception {
  const ClaimRefusalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Raised when trying to claim a node that already has an owner.
class ClaimAlreadyClaimedException extends ClaimRefusalException {
  const ClaimAlreadyClaimedException([
    super.message = 'This node already has an owner.',
  ]);
}

/// Raised when the one-time launch code is wrong or rejected.
class ClaimCodeRefusedException extends ClaimRefusalException {
  const ClaimCodeRefusedException([
    super.message = 'Invalid claim code.',
  ]);
}
