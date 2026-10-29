import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

/// This device, registered by the administrator as a shop-floor PIN tablet.
///
/// The token is the only thing that makes a four-digit PIN safe: the server
/// accepts a PIN only together with it. It lives in the platform keychain, like
/// every other credential, and survives a person signing out — the tablet
/// stays a PIN tablet until the administrator revokes it.
@immutable
class KioskDevice {
  const KioskDevice({
    required this.serverUrl,
    required this.token,
    required this.label,
  });

  factory KioskDevice.fromJson(Map<String, dynamic> json) => KioskDevice(
    serverUrl: json['serverUrl'] as String? ?? '',
    token: json['token'] as String? ?? '',
    label: json['label'] as String? ?? '',
  );

  final String serverUrl;
  final String token;
  final String label;

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'token': token,
    'label': label,
  };
}

abstract interface class KioskStore {
  Future<KioskDevice?> read();
  Future<void> write(KioskDevice device);
  Future<void> clear();
}

class SecureKioskStore implements KioskStore {
  const SecureKioskStore(this._storage);

  static const _key = 'auth.kiosk';

  final FlutterSecureStorage _storage;

  @override
  Future<KioskDevice?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final device = KioskDevice.fromJson(decoded);
      return device.token.isEmpty ? null : device;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(KioskDevice device) =>
      _storage.write(key: _key, value: jsonEncode(device.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final kioskStoreProvider = Provider<KioskStore>(
  (ref) => const SecureKioskStore(FlutterSecureStorage()),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final kioskDeviceProvider = FutureProvider.autoDispose<KioskDevice?>(
  (ref) => ref.watch(kioskStoreProvider).read(),
);
