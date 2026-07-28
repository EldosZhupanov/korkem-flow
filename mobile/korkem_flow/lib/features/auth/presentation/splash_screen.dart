import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Shown only while the stored credential is being restored and revalidated.
///
/// Deliberately plain and deliberately brief: a splash screen exists to cover a
/// decision the app has not finished making, not to advertise. The router
/// leaves it the instant the session provider settles.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).appTitle,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox.square(
              dimension: AppIconSize.normal,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
