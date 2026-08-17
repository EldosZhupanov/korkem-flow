import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Runtime configuration.
///
/// Injected at build time via `--dart-define`/`--dart-define-from-file` so no
/// environment detail is baked into source control. The defaults are
/// development defaults and are deliberately obvious about it.
@immutable
class AppConfig {
  const AppConfig({required this.baseUrl, required this.flavor});

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      baseUrl: String.fromEnvironment(
        'KORKEM_BASE_URL',
        defaultValue: 'http://korkem.localhost:8000',
      ),
      flavor: String.fromEnvironment(
        'KORKEM_FLAVOR',
        defaultValue: 'dev',
      ),
    );
  }

  final String baseUrl;
  final String flavor;

  bool get isProduction => flavor == 'prod';

  /// Hosts that only ever mean "this machine" — a development bench, or the
  /// address an Android emulator reaches its host on.
  static const _localHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
    '10.0.2.2',
  };

  /// Refuses a production build that would ship a development server.
  ///
  /// The compiled base URL is only a *default* — a user types their own server
  /// at sign-in — which is exactly why getting it wrong is quiet. A release
  /// built without `--dart-define=KORKEM_BASE_URL=...` points every first-run
  /// user at `http://korkem.localhost:8000`, which resolves to their own phone
  /// and simply never answers.
  ///
  /// So a `prod` build asserts what `docs/privacy_policy.md` already promises
  /// users: HTTPS, and a real host. Called from `main()`, before the first
  /// frame, so a misconfigured build fails loudly at startup instead of looking
  /// like a network problem to somebody who cannot fix it.
  void validate() {
    if (!isProduction) return;

    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw StateError(
        'KORKEM_BASE_URL is not a usable URL for a production build: '
        '"$baseUrl".',
      );
    }
    if (uri.scheme != 'https') {
      throw StateError(
        'A production build must talk HTTPS. KORKEM_BASE_URL is "$baseUrl".',
      );
    }
    if (_localHosts.contains(uri.host) || uri.host.endsWith('.localhost')) {
      throw StateError(
        'KORKEM_BASE_URL points at this device ("${uri.host}"), which cannot '
        'be right for a production build. Pass the real host with '
        '--dart-define=KORKEM_BASE_URL=https://<host>.',
      );
    }
  }
}

/// Overridden in tests and at bootstrap.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
