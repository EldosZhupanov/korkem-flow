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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          const Entrance(child: AppLogo()),
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
