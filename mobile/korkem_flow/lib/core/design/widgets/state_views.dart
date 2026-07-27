import 'dart:async';

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Shimmering skeleton that mirrors the real row layout.
///
/// Mirroring the layout is the whole point: a centred spinner causes a visible
/// jump when content arrives, which reads as jank even when it is fast.
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({this.rows = 5, this.rowHeight = 88, super.key});

  final int rows;
  final double rowHeight;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          height: widget.rowHeight,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.4 + (_controller.value * 0.3)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

/// Empty state: one icon, one sentence, at most one action.
///
/// Never a bare "No data" — that tells the user nothing about what to do next.
class EmptyView extends StatelessWidget {
  const EmptyView({
    this.title,
    this.message,
    this.icon = AppIcons.empty,
    this.onAction,
    this.actionLabel,
    super.key,
  });

  final String? title;
  final String? message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _CenteredMessage(
      icon: icon,
      iconColor: theme.colorScheme.outline,
      title: title ?? l10n.emptyTitle,
      message: message ?? l10n.emptyGeneric,
      actionLabel: actionLabel,
      onAction: onAction,
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.illustration, color: iconColor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null && message != title) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
