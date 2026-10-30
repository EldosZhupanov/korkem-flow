import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';

/// Where credentials live between launches.
///
/// An interface, not just the concrete class, so tests never touch the platform
/// keychain — on Linux that is libsecret, which needs a running D-Bus session
/// and is simply absent in a test runner.
abstract interface class CredentialStore {
  Future<AuthCredentials?> read();
  Future<void> write(AuthCredentials credentials);

  /// The server this credential belongs to. Stored alongside it because a
  /// credential minted against one bench is meaningless on another, and users
  /// do move between a staging and a production site.
  Future<String?> readServerUrl();
  Future<void> writeServerUrl(String url);

  Future<void> clear();
}

/// Keychain on iOS, EncryptedSharedPreferences on Android, libsecret on Linux.
class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore(this._storage);

  static const _credentialsKey = 'auth.credentials';
  static const _serverKey = 'auth.server';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthCredentials?> read() async {
    final raw = await _storage.read(key: _credentialsKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthCredentials.fromJson(decoded);
    } on FormatException {
      // A corrupt entry is indistinguishable from no entry as far as the user
      // is concerned: both mean "sign in again".
      return null;
    }
  }

  @override
  Future<void> write(AuthCredentials credentials) =>
      _storage.write(key: _credentialsKey, value: jsonEncode(credentials));

  @override
  Future<String?> readServerUrl() => _storage.read(key: _serverKey);

  @override
  Future<void> writeServerUrl(String url) =>
      _storage.write(key: _serverKey, value: url);

  @override
  Future<void> clear() => _storage.delete(key: _credentialsKey);
}

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => const SecureCredentialStore(FlutterSecureStorage()),
);
