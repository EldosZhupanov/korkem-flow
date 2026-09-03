import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Where the assistant's answer arrives from.
///
/// An interface, so the repository can be tested without a server and so a
/// different transport — long polling, say, on a network that blocks
/// websockets — is a different implementation rather than an edit.
abstract class AssistantChannel {
  /// Events published to this user's realtime room, decoded.
  Future<Stream<Map<String, dynamic>>> events();

  /// Whether the channel currently has a live connection.
  ///
  /// Separate from [events] because a turn failing and the *channel* being down
  /// are different facts, and until now the app could not tell them apart: a
  /// socket that dropped looked exactly like a model that had not answered yet.
  Stream<ChannelStatus> get status;

  Future<void> dispose();
}

/// Where the realtime channel stands.
enum ChannelStatus {
  connected,
  disconnected,

  /// Trying to come back. Distinct from [disconnected] so a UI can say
  /// "reconnecting" rather than "offline", which are different promises.
  reconnecting,

  /// Gave up. Terminal until something asks again — see
  /// `FrappeSocketChannel.reconnectAttempts`.
  failed,
}

/// Frappe's socket.io channel.
///
/// ## Three things that make this work, all verified against the running bench
///
/// Frappe's `authenticate_with_frappe` middleware was read rather than guessed
/// at, and it imposes three constraints that each fail *silently* — the socket
/// simply never connects, with no useful error on the device:
///
/// 1. **The namespace is the site name.** Not `/`, not a path — the middleware
///    compares `socket.nsp.name` against the site and rejects a mismatch.
/// 2. **`Origin` must share a hostname with `Host`.** Sending no Origin, or a
///    different one, is refused as an invalid origin.
/// 3. **Authorization works.** The middleware accepts *either* a session
///    cookie or an `Authorization` header, so the API key pair the app already
///    holds is enough — no separate login for the socket.
///
/// Confirmed by driving the handshake by hand: with these headers, the server
/// answered `40/<site>,{"sid":...}` — Socket.IO's "namespace connected" packet
/// — rather than an error.
class FrappeSocketChannel implements AssistantChannel {
  FrappeSocketChannel({
    required this.baseUrl,
    required this.siteName,
    required this.credentials,
    this.event = defaultEvent,
  });

  /// The realtime event the gateway publishes on. One name carrying a `type`,
  /// so a new kind of update needs no client release.
  static const defaultEvent = 'korkem_ai_chat';

  /// Frappe serves socket.io on its own port, not the web port.
  static const socketPort = 9000;

  final String baseUrl;
  final String siteName;
  final AuthCredentials credentials;
  final String event;

  /// How many times to try before reporting [ChannelStatus.failed].
  ///
  /// Bounded rather than infinite: a client retrying for ever against a server
  /// that is not coming back looks identical, to the user, to one that is still
  /// working. A terminal state is something they can act on.
  static const reconnectAttempts = 8;

  io.Socket? _socket;
  StreamController<Map<String, dynamic>>? _controller;
  final _status = StreamController<ChannelStatus>.broadcast();

  @override
  Stream<ChannelStatus> get status => _status.stream;

  /// Records a transport event without ever recording what it carried.
  ///
  /// Connection lifecycle only — no payload, no headers, no credential. The
  /// reason strings socket.io produces ("transport close", "ping timeout") are
  /// exactly what is needed to tell a dropped network from a rejected auth,
  /// and none of them contain anything private.
  void _note(String event, [Object? detail]) {
    final at = DateTime.now().toIso8601String().substring(11, 19);
    debugPrint('[$at] socket.$event${detail == null ? '' : ' $detail'}');
  }

  /// The socket endpoint, derived from the configured server.
  ///
  /// Derived rather than configured separately so there is one server setting
  /// to get wrong instead of two — and so pointing the app at an emulator host
  /// moves the socket with it.
  ///
  /// ## Почему порт подменяется не всегда
  ///
  /// На стенде разработчика socket.io слушает свой порт 9000, и туда надо
  /// стучаться напрямую. На настоящем узле его наружу не публикуют вовсе:
  /// снаружи открыты только 22, 80 и 443, а реальное время идёт через тот же
  /// TLS-адрес, что и всё остальное — Caddy разбирает `/socket.io` и передаёт
  /// внутрь.
  ///
  /// Подменяя порт всегда, приложение стучалось в закрытый 9000 и молчало.
  /// Сервер при этом отвечал: ход выполнялся за секунды, событие уходило в
  /// сокет, которого никто не слушал, а человек читал «не удалось связаться с
  /// KORKEM» — сообщение про сеть там, где сеть работала.
  ///
  /// Признак — схема. `https` означает, что перед узлом стоит терминатор TLS,
  /// а он по определению один на 443: незашифрованного socket.io за ним не
  /// бывает.
  Uri get endpoint {
    final base = Uri.parse(baseUrl);
    if (base.scheme == 'https') {
      return base.replace(path: '/$siteName');
    }
    return base.replace(port: socketPort, path: '/$siteName');
  }

  @override
  Future<Stream<Map<String, dynamic>>> events() async {
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _controller = controller;

    final origin = endpoint.replace(path: '').toString();
    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({
          credentials.header.key: credentials.header.value,
          // Routes the loopback request the middleware makes back to the
          // right site. Without it the server infers the site from the Host
          // header, which on an emulator is 10.0.2.2 and matches nothing.
          'X-Frappe-Site-Name': siteName,
          'Origin': origin,
        })
        .disableAutoConnect()
        .setReconnectionAttempts(reconnectAttempts)
        .build();

    final socket = io.io(endpoint.toString(), options)
      ..on(event, (dynamic data) {
        if (data is Map) {
          controller.add(Map<String, dynamic>.from(data));
        }
      })
      ..onConnect((_) {
        _note('connected');
        _status.add(ChannelStatus.connected);
      })
      // A drop is *not* an error. It used to be indistinguishable from one
      // because nothing listened for it at all: the socket went quiet, the
      // turn timed out, and the user was told "offline" forever after. The
      // client reconnects on its own, so this reports rather than fails.
      ..onDisconnect((reason) {
        _note('disconnect', 'reason=$reason');
        _status.add(ChannelStatus.disconnected);
      })
      ..on('reconnect_attempt', (attempt) {
        _note('reconnect_attempt', 'attempt=$attempt');
        _status.add(ChannelStatus.reconnecting);
      })
      ..on('reconnect', (attempt) {
        _note('reconnect', 'attempt=$attempt');
        _status.add(ChannelStatus.connected);
      })
      ..on('reconnect_failed', (_) {
        _note('reconnect_failed');
        _status.add(ChannelStatus.failed);
      })
      // Only these two fail the stream. A *connect* error while the socket is
      // retrying is normal and must not kill a subscriber; it is reported on
      // `status` instead.
      ..onConnectError((error) {
        _note('connect_error', _summarise(error));
        _status.add(ChannelStatus.reconnecting);
      })
      ..onError((error) {
        _note('error', _summarise(error));
        controller._failWith(error);
      })
      ..connect();

    _socket = socket;
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _controller?.close();
    _controller = null;
    await _status.close();
  }

  /// A transport error reduced to something safe to print.
  ///
  /// socket.io hands back an untyped payload that can include the server's
  /// response. Only the message is kept, and it is truncated — a connection
  /// diagnostic is worth logging; a response body is not.
  static String _summarise(Object? error) {
    final text = error is Map ? '${error['message'] ?? error}' : '$error';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}

/// A connection failure, as something with a type.
class _ChannelError implements Exception {
  const _ChannelError(this.detail);

  final String detail;

  @override
  String toString() => 'Assistant channel error: $detail';
}

extension on StreamController<Map<String, dynamic>> {
  /// socket.io reports failures as a dynamic payload, which `addError` will
  /// not take. This is the one place that conversion happens.
  void _failWith(dynamic error) => addError(_ChannelError('$error'));
}

/// What the gateway reports about itself.
@immutable
class AssistantInfo {
  const AssistantInfo({required this.site, required this.event});

  /// The Frappe site name, which is the socket.io namespace.
  final String site;

  /// The realtime event answers arrive on.
  final String event;
}
