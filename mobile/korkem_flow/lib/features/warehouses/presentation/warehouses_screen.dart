import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/warehouses/application/warehouses_controller.dart';
import 'package:korkem_flow/features/warehouses/data/warehouses_repository.dart';
import 'package:korkem_flow/features/warehouses/domain/warehouse_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying the factory warehouses, default shipping assignment,
/// and disabling/enabling storage locations.
///
/// Renaming warehouses is intentionally not supported because ERPNext
/// maintains tree integrity and document history strictly on warehouse
/// document identifiers.
class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehousesAsync = ref.watch(warehousesListProvider);

    return AppScreen(
      title: l10n.warehousesTitle,
      subtitle: l10n.warehousesSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.warehousesCreateButton,
          icon: const Icon(AppIcons.add),
          onPressed: () => _openCreateDialog(context),
        ),
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(warehousesListProvider),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(warehousesListProvider);
          await ref.read(warehousesListProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WarehouseTipBanner(),
                const SizedBox(height: AppSpacing.lg),
                warehousesAsync.when(
                  data: (warehouses) => _WarehousesContent(
                    warehouses: warehouses,
                    onCreateTap: () => _openCreateDialog(context),
                  ),
                  loading: () => const _WarehousesLoading(),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(warehousesListProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => const _CreateWarehouseDialog(),
      ),
    );
  }
}

class _WarehouseTipBanner extends StatelessWidget {
  const _WarehouseTipBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.info,
            color: theme.colorScheme.primary,
            size: AppIconSize.normal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.warehousesTipTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.warehousesTipBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehousesContent extends ConsumerWidget {
  const _WarehousesContent({
    required this.warehouses,
    required this.onCreateTap,
  });

  final List<WarehouseEntry> warehouses;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final activeWarehouses = warehouses.where((w) => !w.disabled).toList();
    final disabledWarehouses = warehouses.where((w) => w.disabled).toList();

    if (warehouses.isEmpty) {
      return Entrance(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StateIllustration(
                  icon: AppIcons.empty,
                  dense: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.warehousesEmptyTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.warehousesEmptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onCreateTap,
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.warehousesCreateButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeWarehouses.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel(l10n.warehousesSectionActive),
                TextButton.icon(
                  onPressed: onCreateTap,
                  icon: const Icon(AppIcons.add, size: AppIconSize.small),
                  label: Text(l10n.warehousesCreateButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeWarehouses.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final warehouse = activeWarehouses[index];
                return _WarehouseCard(
                  warehouse: warehouse,
                  onSetShippingDefault: () => _setShippingDefault(
                    context,
                    ref,
                    warehouse,
                  ),
                  onDisable: () => _openDisableDialog(context, warehouse),
                  onEnable: () => _openEnableDialog(context, warehouse),
                );
              },
            ),
          ],
          if (disabledWarehouses.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.warehousesSectionDisabled),
            const SizedBox(height: AppSpacing.xs),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: disabledWarehouses.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final warehouse = disabledWarehouses[index];
                return _WarehouseCard(
                  warehouse: warehouse,
                  onSetShippingDefault: () => _setShippingDefault(
                    context,
                    ref,
                    warehouse,
                  ),
                  onDisable: () => _openDisableDialog(context, warehouse),
                  onEnable: () => _openEnableDialog(context, warehouse),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setShippingDefault(
    BuildContext context,
    WidgetRef ref,
    WarehouseEntry warehouse,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await ref
          .read(warehousesRepositoryProvider)
          .setShippingDefault(warehouse: warehouse.warehouse);
      ref.invalidate(warehousesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showDone(
          l10n.warehousesSetShippingDefaultSuccess(updated.name),
        );
      }
    } on FrappeException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFailureMessage(e.message);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFailure(e, l10n);
      }
    }
  }

  void _openDisableDialog(BuildContext context, WarehouseEntry warehouse) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ConfirmDisableDialog(warehouse: warehouse),
      ),
    );
  }

  void _openEnableDialog(BuildContext context, WarehouseEntry warehouse) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ConfirmEnableDialog(warehouse: warehouse),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({
    required this.warehouse,
    required this.onSetShippingDefault,
    required this.onDisable,
    required this.onEnable,
  });

  final WarehouseEntry warehouse;
  final VoidCallback onSetShippingDefault;
  final VoidCallback onDisable;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final isShippingDefault = warehouse.isShippingDefault;
    final isDisabled = warehouse.disabled;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isShippingDefault
                ? theme.colorScheme.primaryContainer
                : (isDisabled
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.secondaryContainer),
            foregroundColor: isShippingDefault
                ? theme.colorScheme.onPrimaryContainer
                : (isDisabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSecondaryContainer),
            child: const Icon(
              AppIcons.warehouse,
              size: AppIconSize.normal,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDisabled
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (warehouse.warehouse != warehouse.name) ...[
                  Text(
                    warehouse.warehouse,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(
                  l10n.warehousesPositionsCount(warehouse.positions),
                  style: AppTypography.tabular(
                    theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ) ??
                        const TextStyle(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isShippingDefault)
            StatusChip(
              label: l10n.warehousesShippingDefaultBadge,
              intent: StatusIntent.success,
            )
          else if (isDisabled)
            StatusChip(
              label: l10n.warehousesStatusDisabled,
              intent: StatusIntent.neutral,
            ),
          if (isDisabled) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: l10n.warehousesActionEnable,
              icon: const Icon(
                AppIcons.refresh,
                size: AppIconSize.small,
              ),
              onPressed: onEnable,
            ),
          ] else if (!isShippingDefault) ...[
            const SizedBox(width: AppSpacing.xs),
            PopupMenuButton<String>(
              icon: const Icon(
                AppIcons.more,
                size: AppIconSize.small,
              ),
              tooltip: l10n.warehousesSettingsTitle,
              onSelected: (action) {
                if (action == 'shipping_default') {
                  onSetShippingDefault();
                } else if (action == 'disable') {
                  onDisable();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'shipping_default',
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.check,
                        size: AppIconSize.small,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.warehousesActionSetShippingDefault),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'disable',
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.noAccess,
                        size: AppIconSize.small,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.warehousesActionDisable,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateWarehouseDialog extends ConsumerStatefulWidget {
  const _CreateWarehouseDialog();

  @override
  ConsumerState<_CreateWarehouseDialog> createState() =>
      _CreateWarehouseDialogState();
}

class _CreateWarehouseDialogState
    extends ConsumerState<_CreateWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final created = await ref
          .read(warehousesRepositoryProvider)
          .createWarehouse(name: name);
      ref.invalidate(warehousesListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showDone(
          l10n.warehousesCreateSuccess(created.name),
        );
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.warehousesCreateDialogTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.warehousesCreateDialogSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.warehousesNameLabel,
                    hintText: l10n.warehousesNameHint,
                    prefixIcon: const Icon(AppIcons.warehouse),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.warehousesNameError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.actionCancel),
                    ),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: AppIconSize.small,
                              child: CircularProgressIndicator(
                                strokeWidth: AppStroke.focus,
                              ),
                            )
                          : Text(l10n.warehousesCreateButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmDisableDialog extends ConsumerStatefulWidget {
  const _ConfirmDisableDialog({required this.warehouse});

  final WarehouseEntry warehouse;

  @override
  ConsumerState<_ConfirmDisableDialog> createState() =>
      _ConfirmDisableDialogState();
}

class _ConfirmDisableDialogState extends ConsumerState<_ConfirmDisableDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await ref
          .read(warehousesRepositoryProvider)
          .setDisabled(
            warehouse: widget.warehouse.warehouse,
            disabled: true,
          );
      ref.invalidate(warehousesListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showDone(
          l10n.warehousesDisableSuccess(updated.name),
        );
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.warehousesDisableDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.warehousesDisableDialogMessage(widget.warehouse.name),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppIconSize.small,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.warehousesActionDisable),
        ),
      ],
    );
  }
}

class _ConfirmEnableDialog extends ConsumerStatefulWidget {
  const _ConfirmEnableDialog({required this.warehouse});

  final WarehouseEntry warehouse;

  @override
  ConsumerState<_ConfirmEnableDialog> createState() =>
      _ConfirmEnableDialogState();
}

class _ConfirmEnableDialogState extends ConsumerState<_ConfirmEnableDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await ref
          .read(warehousesRepositoryProvider)
          .setDisabled(
            warehouse: widget.warehouse.warehouse,
            disabled: false,
          );
      ref.invalidate(warehousesListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showDone(
          l10n.warehousesEnableSuccess(updated.name),
        );
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.warehousesEnableDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.warehousesEnableDialogMessage(widget.warehouse.name),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppIconSize.small,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.warehousesActionEnable),
        ),
      ],
    );
  }
}

class _WarehousesLoading extends StatelessWidget {
  const _WarehousesLoading();

  @override
  Widget build(BuildContext context) {
    return const ListSkeleton(rows: 4);
  }
}
