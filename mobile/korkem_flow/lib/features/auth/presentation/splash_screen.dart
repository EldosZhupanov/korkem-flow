import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Shown only while the stored credential is being restored and revalidated.
///
/// A splash exists to cover a decision the app has not finished making, not to
/// advertise, so this stays brief and calm. What it must not do is *flash*: the
/// router leaves the instant the session provider settles, which on a warm
/// start is a frame or two.
///
/// Hence the delayed progress indicator. A spinner that appears and vanishes
/// inside 200ms is noise — it reads as a glitch rather than as feedback. It is
/// held back until the wait is long enough to be worth explaining, so a fast
/// restore shows the mark and nothing else, and a slow one still reassures.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final duration = motionOf(context, AppDuration.slow);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The mark settles rather than arrives: it starts a touch small and
            // fully transparent and eases to rest, which reads as the app
            // coming into focus instead of an element being inserted.
            const AppLogo()
                .animate()
                .fadeIn(duration: duration, curve: AppCurves.enter)
                .scaleXY(
                  begin: _settleFrom,
                  duration: duration,
                  curve: AppCurves.emphasised,
                ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineMedium,
            ).animate().fadeIn(
              // Trails the mark, so the eye lands on the logo first and the
              // name confirms it. Together they would read as one flat
              // block sliding in.
              delay: duration ~/ 2,
              duration: duration,
              curve: AppCurves.enter,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              // Reserved whether or not the indicator is showing, so its
              // arrival never nudges the mark off centre.
              height: AppSpacing.xs,
              width: AppIconSize.illustration,
              child: const _SlowStartIndicator().animate().fadeIn(
                // Held back until the app owes the user an explanation.
                delay: AppDuration.deliberate,
                duration: duration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the mark eases in from. Close to rest on purpose — a mark that grows
/// from half size is an intro sequence, and nobody wants one twice a day.
const double _settleFrom = 0.92;

/// A hairline progress track, not a spinner.
///
/// A circular indicator draws the eye to itself, and at this moment the only
/// thing worth looking at is the mark. This sits underneath and reads as a
/// footnote.
class _SlowStartIndicator extends StatelessWidget {
  const _SlowStartIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: LinearProgressIndicator(
        minHeight: AppSpacing.xs,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
