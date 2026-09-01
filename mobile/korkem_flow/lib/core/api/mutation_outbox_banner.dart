import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Persistent evidence that a write is waiting or needs the person's attention.
class MutationOutboxBanner extends ConsumerWidget {
  const MutationOutboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(mutationOutboxProvider);
    final snapshot =
        ref.watch(mutationOutboxSnapshotProvider).value ?? outbox.snapshot;
    if (snapshot.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasRejected = snapshot.rejected.isNotEmpty;
    final color = !hasRejected
        ? context.statusColors.warning
        : context.statusColors.danger;

    return Material(
      color: color.withValues(alpha: AppTint.surface),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () {
            try {
              unawaited(context.push(Routes.outbox));
            } on Object {
              // Ignore if not in a GoRouter context (e.g. isolated unit test)
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  !hasRejected ? AppIcons.offline : AppIcons.danger,
                  size: AppIconSize.small,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasRejected)
                        Text(
                          l10n.outboxRejectedPending(snapshot.rejectedCount),
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (snapshot.pendingCount > 0)
                        Text(
                          l10n.outboxPending(snapshot.pendingCount),
                          style: !hasRejected
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (snapshot.pendingCount > 0)
                  TextButton(
                    onPressed: () => unawaited(
                      outbox.retryPending(ref.read(frappeClientProvider)),
                    ),
                    child: Text(l10n.outboxRetry),
                  ),
                const Icon(AppIcons.forward, size: AppIconSize.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
