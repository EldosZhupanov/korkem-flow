import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox_store.dart';
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

/// A queued command and the terminal answer received while replaying it.
@immutable
final class RejectedMutation {
  const RejectedMutation({required this.command, required this.reason});

  final PendingMutation command;
  final String? reason;

  String get key => command.key;
  String get path => command.path;
  Map<String, dynamic> get params => command.params;
}

/// Everything the shell needs to make the outbox visible.
@immutable
final class OutboxSnapshot {
  const OutboxSnapshot({
    this.pending = const [],
    this.rejected = const [],
  });

  final List<PendingMutation> pending;
  final List<RejectedMutation> rejected;

  int get pendingCount => pending.length;
  int get rejectedCount => rejected.length;
  bool get isEmpty => pending.isEmpty && rejected.isEmpty;
}

/// Signals that a write is safe in the outbox, but has no server answer yet.
@immutable
final class MutationQueued implements Exception {
  const MutationQueued(this.key);

  final String key;
}

/// Durable client half of the mutation idempotency contract.
///
/// The command and its key are created together and stored before the first
/// network attempt. A retry after a process death therefore carries the same
/// key and frozen payload. Only transport failures stay pending; a server
/// refusal during replay is a terminal answer.
class MutationOutbox {
  MutationOutbox({
    IdempotencyKeyFactory? keyFactory,
    this._store,
    MutationOutboxScope? scope,
    this.storageTimeout = const Duration(seconds: 2),
  }) : _keyFactory = keyFactory ?? _newRandomKey {
    if (scope != null) unawaited(activate(scope));
  }

  final IdempotencyKeyFactory _keyFactory;
  final MutationOutboxStore? _store;
  final Duration storageTimeout;
  final List<PendingMutation> _pending = [];
  final List<RejectedMutation> _rejected = [];
  final StreamController<OutboxSnapshot> _snapshots =
      StreamController<OutboxSnapshot>.broadcast();

  bool _retrying = false;
  MutationOutboxScope? _scope;
  Future<void>? _ready;

  /// Enough recent refusals for one app session without an unbounded log.
  static const maxRejected = 20;

  OutboxSnapshot get snapshot => OutboxSnapshot(
    pending: List<PendingMutation>.unmodifiable(_pending),
    rejected: List<RejectedMutation>.unmodifiable(_rejected),
  );

  Stream<OutboxSnapshot> get snapshots => _snapshots.stream;

  /// Changes the active account/site and restores only that account's records.
  ///
  /// Records for another identity remain encrypted under their own key. They
  /// are never present in memory and therefore cannot be replayed by a user
  /// who signed in afterwards.
  Future<void> activate(MutationOutboxScope? scope) {
    _scope = scope;
    _pending.clear();
    _rejected.clear();
    _emit();
    if (scope == null || _store == null) {
      _ready = null;
      return Future<void>.value();
    }

    final ready = _restore(scope);
    _ready = ready;
    return ready;
  }

  Future<Map<String, dynamic>> execute(
    FrappeClient client,
    String path, {
    required Map<String, dynamic> params,
  }) async {
    await _ensureReady();
    final command = PendingMutation(
      key: _keyFactory(),
      path: path,
      params: _freezeParams(params),
    );

    // Persist before any network I/O. The server receives this exact key after
    // a restart, so an ambiguous response remains safe to replay.
    _pending.add(command);
    await _persist();
    _emit();

    try {
      final response = await _send(client, command);
      _pending.remove(command);
      await _persist();
      _emit();
      return response;
    } on NetworkFailure {
      throw MutationQueued(command.key);
    } on Object {
      _pending.remove(command);
      await _persist();
      _emit();
      rethrow;
    }
  }

  /// Retry each queued command once, in the order the person created it.
  Future<void> retryPending(FrappeClient client) async {
    await _ensureReady();
    if (_retrying || _pending.isEmpty) return;
    _retrying = true;
    try {
      for (final command in List<PendingMutation>.of(_pending)) {
        try {
          final response = await _send(client, command);
          _pending.remove(command);
          final refusal = _refusalFrom(response);
          if (refusal == null) {
            await _persist();
            _emit();
          } else {
            await _reject(command, refusal.reason);
          }
        } on NetworkFailure {
          // The link is still down. Preserve this command and everything after
          // it; a later resume, successful request or manual tap tries again.
          return;
        } on FrappeException catch (error) {
          _pending.remove(command);
          await _reject(command, error.message);
        } on Object {
          _pending.remove(command);
          await _reject(command, null);
        }
      }
    } finally {
      _retrying = false;
    }
  }

  Future<void> dismissRejected(String key) async {
    await _ensureReady();
    final before = _rejected.length;
    _rejected.removeWhere((item) => item.key == key);
    if (_rejected.length == before) return;
    await _persist();
    _emit();
  }

  Future<void> clearRejected() async {
    await _ensureReady();
    if (_rejected.isEmpty) return;
    _rejected.clear();
    await _persist();
    _emit();
  }

  /// Clears only the active account's in-memory records and durable snapshot.
  Future<void> clear() async {
    await _ensureReady();
    if (_pending.isEmpty && _rejected.isEmpty) return;
    _pending.clear();
    _rejected.clear();
    await _persist();
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

  Future<void> _reject(PendingMutation command, String? reason) async {
    _rejected.add(RejectedMutation(command: command, reason: reason));
    if (_rejected.length > maxRejected) {
      _rejected.removeRange(0, _rejected.length - maxRejected);
    }
    await _persist();
    _emit();
  }

  Future<void> _restore(MutationOutboxScope scope) async {
    try {
      final raw = await _store!
          .read(scope)
          .timeout(
            storageTimeout,
            onTimeout: () => null,
          );
      if (_scope != scope || raw == null) return;
      final restored = _decode(raw);
      _pending.addAll(restored.pending);
      _rejected.addAll(restored.rejected);
      _emit();
    } on Object {
      // Persistence is best effort. A broken keychain must not make every
      // production command unusable for the rest of the app session.
    }
  }

  Future<void> _ensureReady() async {
    final ready = _ready;
    if (ready != null) await ready;
  }

  Future<void> _persist() async {
    final store = _store;
    final scope = _scope;
    if (store == null || scope == null) return;
    try {
      await store.write(scope, jsonEncode(_encode())).timeout(storageTimeout);
    } on Object {
      // Keep the in-memory queue operational if protected storage is absent,
      // locked or stuck. The next mutation attempts a fresh snapshot write.
    }
  }

  Map<String, Object?> _encode() => {
    'version': 1,
    'pending': _pending.map(_pendingToJson).toList(),
    'rejected': _rejected
        .map(
          (rejection) => {
            'command': _pendingToJson(rejection.command),
            'reason': rejection.reason,
          },
        )
        .toList(),
  };

  static OutboxSnapshot _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported mutation outbox snapshot');
    }
    return OutboxSnapshot(
      pending: _decodeList(decoded['pending']).map(_pendingFromJson).toList(),
      rejected: _decodeList(decoded['rejected'])
          .map(
            (item) => RejectedMutation(
              command: _pendingFromJson(_requiredMap(item['command'])),
              reason: item['reason'] as String?,
            ),
          )
          .toList(),
    );
  }

  static List<Map<String, dynamic>> _decodeList(Object? value) {
    if (value is! List) throw const FormatException('Invalid mutation list');
    return value.map(_requiredMap).toList();
  }

  static Map<String, dynamic> _requiredMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid mutation record');
    }
    return value;
  }

  static Map<String, Object?> _pendingToJson(PendingMutation command) => {
    'key': command.key,
    'path': command.path,
    'params': command.params,
  };

  static PendingMutation _pendingFromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final path = json['path'];
    final params = json['params'];
    if (key is! String || path is! String || params is! Map<String, dynamic>) {
      throw const FormatException('Invalid mutation command');
    }
    return PendingMutation(key: key, path: path, params: _freezeParams(params));
  }

  static _Refusal? _refusalFrom(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    if (raw is! Map || raw['status'] != 'blocked') return null;
    final message = raw['message'];
    return _Refusal(message is String && message.isNotEmpty ? message : null);
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

final class _Refusal {
  const _Refusal(this.reason);

  final String? reason;
}
