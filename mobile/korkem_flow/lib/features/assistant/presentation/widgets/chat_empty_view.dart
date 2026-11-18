import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What greets someone opening the app.
///
/// The mark, a question, and four things worth asking. The suggestions are not
/// decoration: this assistant understands a small set of requests, and showing
/// that set is the difference between a user learning what it does in two
/// seconds and discovering it by failing.
class ChatEmptyView extends StatelessWidget {
  const ChatEmptyView({required this.onSuggestion, super.key});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final suggestions = [
      l10n.chatSuggestDeals,
      l10n.chatSuggestAttention,
      l10n.chatSuggestOverdue,
      l10n.chatSuggestProduction,
    ];

    // Centred when it fits, scrollable when it does not — which needs the
    // viewport height, because a `Column` inside a scroll view is laid out
    // against unbounded height and `MainAxisAlignment.center` there is a no-op.
    // Without this the greeting and the suggestions sat below the fold in
    // landscape and the screen opened on a lone logo, looking broken.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - AppSpacing.xl * 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Entrance(
                child: _BrandMark(
                  wide: constraints.maxWidth >= AppBreakpoints.compact,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Entrance(
                index: 1,
                child: Text(
                  l10n.chatGreeting,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final (index, suggestion) in suggestions.indexed)
                Entrance(
                  index: index + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _Suggestion(
                      label: suggestion,
                      onTap: () => onSuggestion(suggestion),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primary.withValues(alpha: AppTint.surfaceFaint),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// The company's full lockup — rules, KÖRKEM, SINCE 2021 — raised off the
/// field, with one pass of light when the screen opens (owner, 18.11.2026:
/// «полное название вместо значка… как в 3д»). It used to be the ornamented
/// Ö alone, which named nothing on the screen people open first.
///
/// The relief is three still layers of the same mask: a soft shadow below, a
/// thin lit edge above, and the face itself in a gradient lighter at the top
/// and deeper at the foot, as if lit from above. The light is one pass and
/// then the animation stops — nothing keeps running on a screen opened forty
/// times a shift, and with reduced motion there is no pass at all.
///
/// The glow behind stays a radial gradient that ends at full transparency, as
/// before: it has no edge to notice, whatever shape it lies behind.
class _BrandMark extends StatefulWidget {
  const _BrandMark({required this.wide});

  final bool wide;

  @override
  State<_BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<_BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this);
  bool _started = false;

  /// How much lighter the top of the face is, and how much deeper its foot.
  static const double _lift = 0.12;
  static const double _sink = 0.1;

  /// The width of the band of light, as a share of the logo.
  static const double _band = 0.12;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final duration = motionOf(context, AppDuration.shine);
    if (duration == Duration.zero) return;
    // The wait is part of the animation rather than a timer: the light passes
    // once the entrance has settled, and nothing is left pending behind it.
    _shine.duration = AppDuration.deliberate + duration;
    unawaited(_shine.forward());
  }

  /// The share of [_shine] spent waiting for the entrance to settle.
  double get _wait =>
      AppDuration.deliberate.inMilliseconds /
      (_shine.duration?.inMilliseconds ?? 1);

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Color _lightness(Color c, double by) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + by).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.primary;
    final width = widget.wide ? AppLogoSize.lockup : AppLogoSize.lockupCompact;
    final top = _lightness(tint, _lift);
    final foot = _lightness(tint, -_sink);
    final light = _lightness(tint, _lift * 3);

    Widget logo(Color color) =>
        AppLogo(layout: LogoLayout.lockup, size: width, color: color);

    final raised = Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, AppSpacing.xs),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AppSpacing.xs,
              sigmaY: AppSpacing.xs,
            ),
            child: logo(
              theme.colorScheme.shadow.withValues(alpha: AppTint.relief),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -AppStroke.hairline),
          child: logo(light),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, tint, foot],
          ).createShader(bounds),
          child: logo(tint),
        ),
        AnimatedBuilder(
          animation: _shine,
          builder: (context, child) {
            final t = Interval(_wait.clamp(0.0, 1.0), 1).transform(_shine.value);
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final at = -_band + t * (1 + _band * 2);
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  light.withValues(alpha: 0),
                  light,
                  light.withValues(alpha: 0),
                ],
                stops: [
                  for (final stop in [at - _band, at, at + _band])
                    stop.clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: child,
            );
          },
          child: logo(light),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            tint.withValues(alpha: AppTint.glow),
            tint.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: raised,
      ),
    );
  }
}
