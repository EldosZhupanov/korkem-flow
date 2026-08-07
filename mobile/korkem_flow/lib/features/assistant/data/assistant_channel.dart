import 'dart:async';

import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:meta/meta.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Where the assistant's answer arrives from.
///
/// An interface, so the repository can be tested without a server and so a
/// different transport — long polling, say, on a network that blocks
/// websockets — is a different implementation rather than an edit.
abstract class AssistantChannel {
  /// Events published to this user's realtime room, decoded.
  Future<Stream<Map<String, dynamic>>> events();

  Future<void> dispose();
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

  io.Socket? _socket;
  StreamController<Map<String, dynamic>>? _controller;

  /// The socket endpoint, derived from the configured server.
  ///
  /// Derived rather than configured separately so there is one server setting
  /// to get wrong instead of two — and so pointing the app at an emulator host
  /// moves the socket with it.
  Uri get endpoint {
    final base = Uri.parse(baseUrl);
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
        .build();

    final socket = io.io(endpoint.toString(), options)
      ..on(event, (dynamic data) {
        if (data is Map) {
          controller.add(Map<String, dynamic>.from(data));
        }
      })
      // Wrapped rather than passed directly: socket.io hands back a dynamic
      // payload, and `addError` will not accept one.
      ..onConnectError(controller._failWith)
      ..onError(controller._failWith)
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
