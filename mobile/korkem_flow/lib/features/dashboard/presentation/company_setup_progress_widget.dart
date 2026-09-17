import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';

/// Progressive setup card for the furniture workshop owner.
/// Shows progress: 25% after registration -> 50% after inviting employee ->
/// 75% after creating 1st order -> 100% complete.
class CompanySetupProgressWidget extends StatefulWidget {
  const CompanySetupProgressWidget({
    super.key,
    this.initialProgress = 0.25,
    this.hasEmployees = false,
    this.hasOrders = false,
  });

  final double initialProgress;
  final bool hasEmployees;
  final bool hasOrders;

  @override
  State<CompanySetupProgressWidget> createState() => _CompanySetupProgressWidgetState();
}

class _CompanySetupProgressWidgetState extends State<CompanySetupProgressWidget> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasEmployees = widget.hasEmployees;
    final hasOrders = widget.hasOrders;

    int stepsDone = 1; // Company created
    if (hasEmployees) stepsDone++;
    if (hasOrders) stepsDone++;

    final progress = stepsDone / 4.0;
    final percent = (progress * 100).toInt();

    // If completely done, do not show
    if (stepsDone >= 4) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(AppIcons.settings, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Настройка компании: $percent%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close, size: 16),
                    tooltip: 'Скрыть',
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Checklist steps
              _buildStepRow(
                context,
                title: 'Компания создана',
                completed: true,
                onTap: null,
              ),
              _buildStepRow(
                context,
                title: 'Пригласить первого сотрудника в цех',
                completed: hasEmployees,
                onTap: () => context.push(Routes.team),
              ),
              _buildStepRow(
                context,
                title: 'Создать первый заказ клиента',
                completed: hasOrders,
                onTap: () => context.push(Routes.orders),
              ),
              _buildStepRow(
                context,
                title: 'Настроить склад и материалы',
                completed: false,
                onTap: () => context.push(Routes.materials),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required String title,
    required bool completed,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              completed ? AppIcons.check : Icons.radio_button_unchecked,
              size: 18,
              color: completed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontWeight: completed ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
            if (!completed && onTap != null)
              Icon(
                AppIcons.forward,
                size: 16,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
