import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/updates/update_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Есть версия новее» — одной строкой и одной кнопкой.
///
/// Полоса, а не окно поверх экрана: человек в цехе открыл приложение, чтобы
/// закрыть операцию, а не чтобы читать про обновления. Окно он закроет не
/// читая, и в следующий раз закроет быстрее.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final update = state.available;
    if (update == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = update.mandatory
        ? context.statusColors.danger
        : context.statusColors.info;

    return Material(
      color: color.withValues(alpha: AppTint.surface),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(AppIcons.down, color: color, size: AppIconSize.small),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.updateAvailable(update.version),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (update.notes.isNotEmpty)
                      Text(
                        update.notes,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (state.downloading)
                // Проценты, а не бесконечный кружок: двадцать четыре мегабайта
                // по цеховому интернету идут долго, и человеку надо видеть, что
                // они идут.
                Text(
                  '${((state.progress ?? 0) * 100).round()}%',
                  style: theme.textTheme.labelLarge,
                )
              else
                FilledButton(
                  onPressed: () =>
                      ref.read(updateControllerProvider.notifier).download(),
                  child: Text(l10n.updateInstall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
