import 'dart:async';

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Shimmering skeleton that mirrors the real row layout.
///
/// Mirroring the layout is the whole point: a centred spinner causes a visible
/// jump when content arrives, which reads as jank even when it is fast.
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({
    this.rows = 5,
    this.rowHeight = AppPlaceholder.rowHeight,
    super.key,
  });

  final int rows;
  final double rowHeight;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour reduced-motion: a perpetual shimmer is exactly the kind of motion
    // users disable it for.
    if (motionOf(context, AppDuration.standard) == Duration.zero) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: widget.rows,
      // Sized to its rows and non-scrolling, so it can stand in for a section
      // inside a larger scroll view as well as fill a screen on its own.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          height: widget.rowHeight,
          decoration: BoxDecoration(
            color: base.withValues(
              alpha:
                  AppTint.shimmerRest +
                  (_controller.value * AppTint.shimmerTravel),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

/// Empty state: an illustration, a headline, a sentence, and a way forward.
///
/// Never a bare "No data" — that tells the user nothing about what to do next.
///
/// The secondary action is optional and should stay that way. A screen with
/// genuinely two things to do offers two; inventing a second button so the
/// layout looks balanced gives the user a decision they did not have.
class EmptyView extends StatelessWidget {
  const EmptyView({
    this.title,
    this.message,
    this.icon = AppIcons.empty,
    this.onAction,
    this.actionLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.tone = StateTone.neutral,
    super.key,
  });

  final String? title;
  final String? message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final StateTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _CenteredMessage(
      icon: icon,
      iconColor: switch (tone) {
        StateTone.neutral => theme.colorScheme.outline,
        StateTone.success => context.statusColors.resolve(
          StatusIntent.success,
        ),
      },
      title: title ?? l10n.emptyTitle,
      message: message ?? l10n.emptyGeneric,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
    );
  }
}

/// The empty state of a paginated list, which every list screen in the app
/// reaches the same way and should therefore leave the same way.
///
/// The two cases are genuinely different and get different offers:
///
/// * **Filtered to nothing** — the user did this, and undoing it is the
///   obvious next step, so "clear filter" leads. Refresh is offered second,
///   because the records they want may simply not exist yet.
/// * **Genuinely empty** — nothing to undo, so refresh leads.
///
/// Refresh is worth a button even though every one of these lists already
/// pulls to refresh. Pull-to-refresh is invisible: it is discoverable only to
/// someone who already suspects it is there, and an empty screen is the exact
/// moment a user is most likely to think the app is broken rather than idle.
class ListEmptyView extends StatelessWidget {
  const ListEmptyView({
    required this.icon,
    required this.onRefresh,
    this.title,
    this.message,
    this.onClearFilter,
    this.tone = StateTone.neutral,
    super.key,
  });

  final IconData icon;
  final String? title;
  final String? message;
  final Future<void> Function() onRefresh;

  /// Null when no filter or search is narrowing the list.
  final VoidCallback? onClearFilter;

  final StateTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFiltered = onClearFilter != null;

    return EmptyView(
      icon: icon,
      tone: tone,
      title: title,
      message: message,
      actionLabel: isFiltered ? l10n.actionClearFilter : l10n.actionRefresh,
      onAction: isFiltered ? onClearFilter : () => unawaited(onRefresh()),
      secondaryActionLabel: isFiltered ? l10n.actionRefresh : null,
      onSecondaryAction: isFiltered ? () => unawaited(onRefresh()) : null,
    );
  }
}

/// Whether reaching this empty state is a neutral fact or an accomplishment.
///
/// An approvals queue with nothing in it means the user has dealt with
/// everything; a search with no matches means nothing at all. Colouring both
/// the same throws away the difference, and the first one is worth a small
/// reward.
enum StateTone { neutral, success }

/// Confirms that something finished, on a screen that would otherwise look
/// simply empty.
///
/// Distinct from [EmptyView] because "there is nothing here" and "you have
/// dealt with everything" are different facts, and a worker clearing an
/// approvals queue has earned the second one.
class SuccessView extends StatelessWidget {
  const SuccessView({
    required this.title,
    this.message,
    this.icon = AppIcons.success,
    this.onAction,
    this.actionLabel,
    this.dense = false,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  /// Set when this shares a screen with content rather than owning it.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: icon,
      iconColor: context.statusColors.resolve(StatusIntent.success),
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      dense: dense,
    );
  }
}

/// Error state carrying the *human* message the backend intended.
///
/// Frappe puts business-rule text inside `_server_messages`; [FrappeException]
/// decodes it, so a factory worker never sees raw JSON.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final failure = error;

    return _CenteredMessage(
      icon: switch (failure) {
        NetworkFailure() => AppIcons.offline,
        PermissionFailure() => AppIcons.noAccess,
        NotFoundFailure() => AppIcons.notFound,
        _ => AppIcons.danger,
      },
      iconColor: theme.colorScheme.error,
      title: switch (failure) {
        NetworkFailure() => l10n.errorOffline,
        PermissionFailure() => l10n.errorNoAccess,
        NotFoundFailure() => l10n.errorNotFound,
        _ => l10n.errorGeneric,
      },
      message: failure is FrappeException ? failure.message : null,
      actionLabel: onRetry == null ? null : l10n.actionRetry,
      onAction: onRetry,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.dense = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrimary = onAction != null && actionLabel != null;
    final hasSecondary =
        onSecondaryAction != null && secondaryActionLabel != null;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(dense ? AppSpacing.lg : AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StateIllustration(icon: icon, color: iconColor, dense: dense),
            SizedBox(height: dense ? AppSpacing.md : AppSpacing.xl),
            // The headline steps up from `titleMedium`: on a screen with no
            // content, this line *is* the content.
            Entrance(
              index: 1,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: dense
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge,
              ),
            ),
            if (message != null && message != title) ...[
              const SizedBox(height: AppSpacing.sm),
              Entrance(
                index: 2,
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (hasPrimary || hasSecondary) ...[
              const SizedBox(height: AppSpacing.xl),
              Entrance(
                index: 3,
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (hasPrimary)
                      FilledButton.tonal(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    if (hasSecondary)
                      TextButton(
                        onPressed: onSecondaryAction,
                        child: Text(secondaryActionLabel!),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
