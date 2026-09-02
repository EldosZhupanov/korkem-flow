import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

/// Identifies the account and site allowed to replay an outbox.
@immutable
final class MutationOutboxScope {
  const MutationOutboxScope({required this.serverUrl, required this.user});

  final String serverUrl;
  final String user;

  String get storageKey {
    final encodedServer = Uri.encodeComponent(serverUrl);
    final encodedUser = Uri.encodeComponent(user);
    return 'mutation-outbox.$encodedServer.$encodedUser';
  }

  @override
  bool operator ==(Object other) =>
      other is MutationOutboxScope &&
      other.serverUrl == serverUrl &&
      other.user == user;

  @override
  int get hashCode => Object.hash(serverUrl, user);
}

/// Protected durable storage for one outbox snapshot per account and site.
abstract interface class MutationOutboxStore {
  Future<String?> read(MutationOutboxScope scope);
  Future<void> write(MutationOutboxScope scope, String value);
}

/// Keychain on Apple platforms, EncryptedSharedPreferences on Android, and
/// the platform secure-storage implementation elsewhere.
class SecureMutationOutboxStore implements MutationOutboxStore {
  const SecureMutationOutboxStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(MutationOutboxScope scope) =>
      _storage.read(key: scope.storageKey);

  @override
  Future<void> write(MutationOutboxScope scope, String value) =>
      _storage.write(key: scope.storageKey, value: value);
}
