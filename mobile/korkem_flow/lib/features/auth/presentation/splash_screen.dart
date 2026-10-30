import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';

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
///
/// The screen is the brand field in both themes rather than following the
/// system. This is the one moment the app is purely itself, and a logo drawn on
/// its own ground is the whole point of having one — the same reason a printed
/// letterhead does not change colour with the room.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final duration = motionOf(context, AppDuration.slow);

    return const ColoredBox(
      color: AppColors.forest,
      child: SafeArea(child: _Mark()),
    ).animate().fadeIn(duration: duration);
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    final duration = motionOf(context, AppDuration.slow);
    final still = duration == Duration.zero;

    const mark = AppLogo(
      size: AppLogoSize.hero,
      color: AppColors.cream,
    );

    const wordmark = Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxl),
      child: AppLogo(
        layout: LogoLayout.lockup,
        size: _lockupWidth,
        color: AppColors.cream,
      ),
    );

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The mark settles rather than arrives: it starts a touch small
              // and fully transparent and eases to rest, which reads as the app
              // coming into focus instead of an element being inserted.
              if (still)
                mark
              else
                mark
                    .animate()
                    .fadeIn(duration: duration, curve: AppCurves.enter)
                    .scaleXY(
                      begin: _settleFrom,
                      duration: duration,
                      curve: AppCurves.emphasised,
                    ),
              // Trails the mark, so the eye lands on the ornament first and the
              // name confirms it. Together they would read as one flat block
              // sliding in.
              if (still)
                wordmark
              else
                wordmark.animate().fadeIn(
                  delay: duration ~/ 2,
                  duration: duration,
                  curve: AppCurves.enter,
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            child: SizedBox(
              // Reserved whether or not the indicator is showing, so its
              // arrival never nudges the mark off centre.
              height: AppSpacing.xs,
              width: AppIconSize.illustration,
              child: still
                  ? const _SlowStartIndicator()
                  : const _SlowStartIndicator().animate().fadeIn(
                      // Held back until the app owes the user an explanation.
                      delay: AppDuration.deliberate,
                      duration: duration,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Wide enough to read, narrow enough to leave the mark its air.
const double _lockupWidth = 208;

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: LinearProgressIndicator(
        minHeight: AppSpacing.xs,
        color: AppColors.cream,
        backgroundColor: AppColors.cream.withValues(alpha: AppTint.surface),
      ),
    );
  }
}
