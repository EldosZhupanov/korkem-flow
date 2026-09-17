import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/updates/update_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Отображает диалог подтверждения обновления KORKEM Flow.
Future<void> showUpdateConfirmationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UpdateConfirmationDialog(),
  );
}

class UpdateConfirmationDialog extends ConsumerWidget {
  const UpdateConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final update = state.available;

    if (update == null) {
      // Если обновление больше недоступно, закрываем диалог
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: AppTint.surface),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(AppIcons.down, color: AppColors.forest),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.updateDialogTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.updateBuildLabel(update.version, update.build),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.notes.isNotEmpty) ...[
              Text(
                l10n.updateNotesTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  update.notes,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.downloading) ...[
              Text(
                l10n.updateDownloading,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: state.progress,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((state.progress ?? 0) * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (Platform.isAndroid)
                    Flexible(
                      child: Text(
                        l10n.updateInstallSystemPrompt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ],
            if (state.failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.statusColors.danger
                      .withValues(alpha: AppTint.surface),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.noAccess,
                      color: context.statusColors.danger,
                      size: AppIconSize.small,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.failure!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.statusColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!update.mandatory && !state.downloading)
          TextButton(
            onPressed: () {
              ref.read(updateControllerProvider.notifier).dismiss();
              Navigator.of(context).pop();
            },
            child: Text(l10n.updateLater),
          ),
        if (isDesktop && !state.downloading)
          OutlinedButton(
            onPressed: () =>
                ref.read(updateControllerProvider.notifier).openExternalUrl(),
            child: Text(l10n.updateOpenBrowser),
          ),
        FilledButton(
          onPressed: state.downloading
              ? null
              : () => ref.read(updateControllerProvider.notifier).download(),
          child: state.downloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.updateNow),
        ),
      ],
    );
  }
}
