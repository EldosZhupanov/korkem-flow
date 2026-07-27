import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Runtime configuration.
///
/// Injected at build time via `--dart-define-from-file` so no environment
/// detail is baked into source control.
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
}

/// Overridden in tests and at bootstrap.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
