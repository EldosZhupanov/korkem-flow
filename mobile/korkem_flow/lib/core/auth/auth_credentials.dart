import 'package:meta/meta.dart';

/// How this session proves who it is on every request.
///
/// Two variants exist because the backend genuinely offers two, and which one a
/// user gets depends on their roles — verified live against the running site
/// (see `docs/backend_api_audit.md` §1):
///
/// * `frappe.core.doctype.user.user.generate_keys` calls `frappe.only_for(
///   "System Manager")`. Administrators can mint a key pair; a `Sales User` —
///   which is 9 of the 11 real accounts — gets a `PermissionError`.
/// * A plain session cookie works for everyone, including writes: an API-only
///   session never has a `csrf_token`, so `auth.py:82` short-circuits.
///   Confirmed by an actual `POST` that applied.
///
/// So the app prefers keys (they do not expire) and falls back to the cookie
/// (it works for every role).
@immutable
sealed class AuthCredentials {
  const AuthCredentials(this.user);

  /// The Frappe user id — an email address, or `Administrator`.
  final String user;

  /// The header this credential contributes to every request.
  MapEntry<String, String> get header;

  Map<String, String> toJson();

  static AuthCredentials? fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! String) return null;

    return switch (json['kind']) {
      ApiKeyCredentials.kind => ApiKeyCredentials(
        user: user,
        apiKey: json['apiKey']! as String,
        apiSecret: json['apiSecret']! as String,
      ),
      SessionCredentials.kind => SessionCredentials(
        user: user,
        sid: json['sid']! as String,
      ),
      _ => null,
    };
  }
}

/// The durable path. Survives session expiry and carries no CSRF surface.
@immutable
final class ApiKeyCredentials extends AuthCredentials {
  const ApiKeyCredentials({
    required String user,
    required this.apiKey,
    required this.apiSecret,
  }) : super(user);

  static const kind = 'apiKey';

  final String apiKey;
  final String apiSecret;

  @override
  MapEntry<String, String> get header =>
      MapEntry('Authorization', 'token $apiKey:$apiSecret');

  @override
  Map<String, String> toJson() => {
    'kind': kind,
    'user': user,
    'apiKey': apiKey,
    'apiSecret': apiSecret,
  };
}

/// The universal path, for users who may not mint keys.
///
/// Expires server-side per `session_expiry`, which the app cannot read — an
/// expired `sid` surfaces as a 401 and is handled the same way as any other
/// credential failure: sign out and ask again.
@immutable
final class SessionCredentials extends AuthCredentials {
  const SessionCredentials({required String user, required this.sid})
    : super(user);

  static const kind = 'session';

  final String sid;

  @override
  MapEntry<String, String> get header => MapEntry('Cookie', 'sid=$sid');

  @override
  Map<String, String> toJson() => {'kind': kind, 'user': user, 'sid': sid};
}
