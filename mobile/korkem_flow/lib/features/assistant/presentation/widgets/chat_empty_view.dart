import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
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

/// The mark, given a little air on a screen with room for it.
///
/// The depth is one layer and nothing else — no blur filter, no gradient stack,
/// no animation that keeps running. On a phone it is omitted: at that size it
/// crowds the mark rather than lifting it, and compositing an extra layer on
/// every frame of the screen people open forty times a shift is the cheap way
/// to make an app feel slow.
///
/// It is a radial gradient and not a `BoxShadow`, which was the first attempt
/// and was visibly wrong on a device: the mark's artwork is taller than it is
/// wide (452 × 591), so a circular shadow behind that box does not cover it and
/// left a bright rectangle around the logo. A gradient that ends at full
/// transparency has no edge to notice, whatever shape the child is.
///
/// [AppTint.glow] is the palette's own name for this — "light falling behind a
/// shape rather than a shape of its own".
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.wide});

  final bool wide;

  /// How far the light reaches past the mark. Generous, because a halo that
  /// stops close to the artwork reads as a plate behind it.
  static const double _haloSize = AppLogoSize.standard * 2.4;

  @override
  Widget build(BuildContext context) {
    if (!wide) return const AppLogo();

    final theme = Theme.of(context);

    return SizedBox.square(
      dimension: _haloSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: AppTint.glow),
              theme.colorScheme.primary.withValues(alpha: 0),
            ],
          ),
        ),
        child: const Center(child: AppLogo()),
      ),
    );
  }
}
