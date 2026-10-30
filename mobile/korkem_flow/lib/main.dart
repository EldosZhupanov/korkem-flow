import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/retry_policy.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A release built without `--dart-define=KORKEM_BASE_URL=...` would default
  // to a development server and fail as though the network were down. Checked
  // before the first frame, so it is a startup error somebody can act on.
  final config = AppConfig.fromEnvironment()..validate();

  // Awaited before the first frame so the stored theme and language are already
  // known when the app builds. Loading them afterwards would render the default
  // and then visibly swap. The native splash covers this.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: retryPolicy,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(config),
      ],
      child: const KorkemFlowApp(),
    ),
  );
}
