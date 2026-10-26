import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:meta/meta.dart';

final pinAdminRepositoryProvider = Provider<PinAdminRepository>(
  (ref) => PinAdminRepository(ref.watch(frappeClientProvider)),
);

/// A person with a PIN, as the administrator sees them.
@immutable
class PinHolder {
  const PinHolder({
    required this.user,
    required this.fullName,
    this.locked = false,
  });

  final String user;
  final String fullName;
  final bool locked;
}

/// A registered PIN tablet.
@immutable
class KioskTablet {
  const KioskTablet({
    required this.device,
    required this.label,
    required this.enabled,
  });

  final String device;
  final String label;
  final bool enabled;
}

/// What only the administrator does: PINs and tablets. The server refuses
/// everybody else; this class only carries the calls.
class PinAdminRepository {
  const PinAdminRepository(this._client);

  static const _base = 'korkem_manufacturing.api.pin_login';

  final FrappeClient _client;

  Future<List<PinHolder>> people() async {
    final rows = (await _client.callMethod('$_base.people'))['message'];
    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map)
          PinHolder(
            user: '${row['user']}',
            fullName: '${row['full_name'] ?? row['user']}',
            locked: row['locked'] == true,
          ),
    ];
  }

  Future<List<KioskTablet>> devices() async {
    final rows = (await _client.callMethod('$_base.devices'))['message'];
    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map)
          KioskTablet(
            device: '${row['device']}',
            label: '${row['label'] ?? ''}',
            enabled: row['enabled'] == 1 || row['enabled'] == true,
          ),
    ];
  }

  Future<void> setPin(String user, String pin) => _client.callMethod(
    '$_base.set_pin',
    post: true,
    params: {'user': user, 'pin': pin},
  );

  Future<void> clearPin(String user) => _client.callMethod(
    '$_base.clear_pin',
    post: true,
    params: {'user': user},
  );

  /// Returns the tablet's token, shown by the server exactly once.
  Future<({String device, String token})> registerDevice(String label) async {
    final message = (await _client.callMethod(
      '$_base.register_device',
      post: true,
      params: {'label': label},
    ))['message'];
    if (message is! Map) throw StateError('No device in the answer.');
    return (
      device: '${message['device']}',
      token: '${message['device_token']}',
    );
  }

  Future<void> revokeDevice(String device) => _client.callMethod(
    '$_base.revoke_device',
    post: true,
    params: {'device': device},
  );
}
