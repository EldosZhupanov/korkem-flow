import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/loopback.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';

/// The server the session talks to, for what is fetched outside the API
/// client: a picture's `/files/...` path becomes a URL against it.
final serverBaseUrlProvider = Provider<String>(
  (ref) =>
      ref.watch(sessionProvider).value?.serverUrl ??
      ref.watch(appConfigProvider).baseUrl,
);

/// A picture stored on the KORKEM server (a public `/files/...` path) —
/// the film decors' swatches (owner, 18.11.2026). Offline, or when the
/// server has no such file, [fallback] stands in.
class ServerImage extends ConsumerWidget {
  const ServerImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  final String path;
  final BoxFit fit;
  final Widget fallback;

  static String urlOf(String base, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$b${path.startsWith('/') ? '' : '/'}${Uri.encodeFull(path)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A bench on this computer: dialled by address (loopback.dart) — a grid
    // of sixty swatches would otherwise wait on each new connection.
    final endpoint = fastLoopback(ref.watch(serverBaseUrlProvider));
    return Image.network(
      urlOf(endpoint.url, path),
      headers: endpoint.headers,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
