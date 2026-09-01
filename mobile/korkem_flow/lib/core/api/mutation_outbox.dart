import 'dart:async';
import 'dart:math';

import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:meta/meta.dart';

typedef IdempotencyKeyFactory = String Function();

/// One write intent that has not reached the server yet.
@immutable
final class PendingMutation {
  const PendingMutation({
    required this.key,
    required this.path,
    required this.params,
  });

  final String key;
  final String path;
  final Map<String, dynamic> params;
}

/// A terminal answer received while replaying a queued command.
@immutable
final class OutboxRejection {
  const OutboxRejection(this.reason);

  final String? reason;
}

/// Everything the shell needs to make the outbox visible.
@immutable
final class OutboxSnapshot {
  const OutboxSnapshot({
    this.pending = const [],
    this.rejection,
  });

  final List<PendingMutation> pending;
  final OutboxRejection? rejection;

  int get pendingCount => pending.length;
  bool get isEmpty => pending.isEmpty && rejection == null;
}

/// Signals that a write is safe in the outbox, but has no server answer yet.
@immutable
final class MutationQueued implements Exception {
  const MutationQueued(this.key);

  final String key;
}

/// In-memory client half of the mutation idempotency contract.
///
/// The command and its key are created together, before the first network
/// attempt. A retry therefore carries the same key and the same frozen payload.
/// Only transport failures are queued; a server refusal is a terminal answer.
class MutationOutbox {
  MutationOutbox({IdempotencyKeyFactory? keyFactory})
    : _keyFactory = keyFactory ?? _newRandomKey;

  final IdempotencyKeyFactory _keyFactory;
  final List<PendingMutation> _pending = [];
  final StreamController<OutboxSnapshot> _snapshots =
      StreamController<OutboxSnapshot>.broadcast(sync: true);

  OutboxRejection? _rejection;
  bool _retrying = false;

  OutboxSnapshot get snapshot => OutboxSnapshot(
    pending: List<PendingMutation>.unmodifiable(_pending),
    rejection: _rejection,
  );

  Stream<OutboxSnapshot> get snapshots => _snapshots.stream;

  Future<Map<String, dynamic>> execute(
    FrappeClient client,
    String path, {
    required Map<String, dynamic> params,
  }) async {
    final command = PendingMutation(
      key: _keyFactory(),
      path: path,
      params: _freezeParams(params),
    );

    try {
      return await _send(client, command);
    } on NetworkFailure {
      _pending.add(command);
      _emit();
      throw MutationQueued(command.key);
    }
  }

  /// Retry each queued command once, in the order the person created it.
  Future<void> retryPending(FrappeClient client) async {
    if (_retrying || _pending.isEmpty) return;
    _retrying = true;
    try {
      for (final command in List<PendingMutation>.of(_pending)) {
        try {
          final response = await _send(client, command);
          _pending.remove(command);
          final refusal = _refusalFrom(response);
          if (refusal != null) _rejection = refusal;
          _emit();
        } on NetworkFailure {
          // The link is still down. Preserve this command and everything after
          // it; a later resume, successful request or manual tap tries again.
          return;
        } on FrappeException catch (error) {
          _pending.remove(command);
          _rejection = OutboxRejection(error.message);
          _emit();
        } on Object {
          _pending.remove(command);
          _rejection = const OutboxRejection(null);
          _emit();
        }
      }
    } finally {
      _retrying = false;
    }
  }

  void clearRejection() {
    if (_rejection == null) return;
    _rejection = null;
    _emit();
  }

  /// A queued command belongs to one authenticated session only.
  void clear() {
    if (_pending.isEmpty && _rejection == null) return;
    _pending.clear();
    _rejection = null;
    _emit();
  }

  void dispose() => _snapshots.close();

  Future<Map<String, dynamic>> _send(
    FrappeClient client,
    PendingMutation command,
  ) => client.callMethod(
    command.path,
    post: true,
    params: {...command.params, 'idempotency_key': command.key},
  );

  void _emit() {
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  static OutboxRejection? _refusalFrom(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    if (raw is! Map || raw['status'] != 'blocked') return null;
    final message = raw['message'];
    return OutboxRejection(
      message is String && message.isNotEmpty ? message : null,
    );
  }

  static Map<String, dynamic> _freezeParams(Map<String, dynamic> params) =>
      Map<String, dynamic>.unmodifiable(
        params.map((key, value) => MapEntry(key, _freeze(value))),
      );

  static Object? _freeze(Object? value) => switch (value) {
    final Map<Object?, Object?> map => Map<String, Object?>.unmodifiable(
      map.map((key, item) => MapEntry('$key', _freeze(item))),
    ),
    final List<Object?> list => List<Object?>.unmodifiable(list.map(_freeze)),
    _ => value,
  };

  static String _newRandomKey() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'mobile-$time-$random';
  }
}
