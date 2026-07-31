import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';

/// A single dashboard metric.
///
/// The value uses `displaySmall`, which carries tabular figures — so a row of
/// tiles keeps its numbers optically aligned instead of drifting, and so the
/// digits do not jostle while the counter rolls.
///
/// Takes the number rather than a formatted string. Formatting here is what
/// lets the tile animate at all, and it puts the "a withheld number is a dash,
/// never a zero" rule in one place instead of at every call site.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.label,
    required this.value,
    this.icon,
    this.intent,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final String label;

  /// Null where the signed-in role may not see this figure. Rendered as a
  /// dash, and never counted to.
  final int? value;
  final IconData? icon;
  final StatusIntent? intent;
  final VoidCallback? onTap;
  final bool isLoading;

  /// The height this tile needs, at the caller's current text scale.
  ///
  /// A grid has to know its row height before it lays a tile out, so the tile
  /// has to be able to say. The alternative — a fixed `childAspectRatio`, which
  /// is what this replaced — ties height to *width*, so a tile cannot grow when
  /// the text inside it does: at the 1.6x scale the app documents as supported,
  /// the content overflowed the tile by 11 pixels.
  ///
  /// Only the text scales. Padding and the gap are physical spacing and stay
  /// put, which is why they are added outside the scaler rather than inside it.
  ///
  /// The label row is the *taller* of its icon and its text, not the text
  /// alone. The icon is a fixed 20dp and the label's line box is 16, so at
  /// normal scale the icon is what sets the row — getting that wrong left the
  /// tile exactly 4px short, which is what the goldens caught.
  static double heightFor(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);

    double lineOf(TextStyle? style) =>
        scaler.scale((style?.fontSize ?? 0) * (style?.height ?? 1));

    final labelRow = math.max(
      AppIconSize.small,
      lineOf(theme.labelMedium),
    );

    return AppSpacing.lg * 2 +
        labelRow +
        AppSpacing.sm +
        lineOf(theme.displaySmall);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = intent == null
        ? theme.colorScheme.primary
        : context.statusColors.resolve(intent!);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.small, color: accent),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            // Placeholder matches the final text height so the tile does not
            // resize when the real number lands.
            Container(
              height: AppPlaceholder.metricHeight,
              width: AppPlaceholder.metricWidth,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            )
          else
            AnimatedCounter(
              value: value,
              placeholder: _withheld,
              style: theme.textTheme.displaySmall?.copyWith(color: accent),
            ),
        ],
      ),
    );
  }
}

/// Shown where the backend returned no number. An em dash: it reads as "not
/// applicable" rather than as a value, which a zero would.
const String _withheld = '—';
