import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/app.dart';
import 'package:korkem_flow/core/api/retry_policy.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Awaited before the first frame so the stored theme and language are already
  // known when the app builds. Loading them afterwards would render the default
  // and then visibly swap. The native splash covers this.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: retryPolicy,
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const KorkemFlowApp(),
    ),
  );
}
