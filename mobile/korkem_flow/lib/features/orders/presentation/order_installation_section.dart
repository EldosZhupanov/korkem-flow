import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/application/order_installation_controller.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Stage 10 Installation section displayed on the Sales Order screen.
class OrderInstallationSection extends ConsumerWidget {
  const OrderInstallationSection({required this.order, super.key});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installationAsync = ref.watch(
      orderInstallationProvider(order.name),
    );

    return switch (installationAsync) {
      AsyncData(:final value) => _InstallationCard(
        order: order,
        installation: value,
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(
          orderInstallationProvider(order.name),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _InstallationCard extends ConsumerStatefulWidget {
  const _InstallationCard({
    required this.order,
    required this.installation,
  });

  final SalesOrder order;
  final OrderInstallation installation;

  @override
  ConsumerState<_InstallationCard> createState() => _InstallationCardState();
}

class _InstallationCardState extends ConsumerState<_InstallationCard> {
  bool _isScheduling = false;
  String? _selectedInstaller;
  DateTime? _installDate;
  String? _errorMessage;
  bool _isSubmitting = false;

  Future<void> _pickInstallDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _installDate = picked);
    }
  }

  Future<void> _submitSchedule() async {
    final l10n = AppLocalizations.of(context);
    var installer = _selectedInstaller;
    if (installer == null || installer.trim().isEmpty) {
      final team = ref.read(teamMembersProvider).value;
      installer = team?.where((m) => m.enabled).firstOrNull?.email;
    }
    if (installer == null || installer.trim().isEmpty) {
      setState(() => _errorMessage = l10n.orderInstallationInstallerLabel);
      return;
    }
    if (_installDate == null) {
      setState(() => _errorMessage = l10n.orderInstallationDateRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final dateStr =
        '${_installDate!.year}-'
        '${_installDate!.month.toString().padLeft(2, '0')}-'
        '${_installDate!.day.toString().padLeft(2, '0')}';

    try {
      await ref
          .read(orderInstallationActionsProvider)
          .schedule(
            salesOrder: widget.order.name,
            installer: installer,
            installOn: dateStr,
          );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isScheduling = false;
        });
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

  Future<void> _showCompleteDialog() async {
    final l10n = AppLocalizations.of(context);
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.orderInstallationCompleteDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.orderInstallationNotesLabel,
                hintText: l10n.orderInstallationNotesHint,
                prefixIcon: const Icon(AppIcons.task),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(AppIcons.check),
            label: Text(l10n.orderInstallationCompleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      final notesText = notesController.text.trim();
      try {
        await ref
            .read(orderInstallationActionsProvider)
            .complete(
              salesOrder: widget.order.name,
              notes: notesText.isNotEmpty ? notesText : null,
            );
        if (mounted) {
          setState(() => _isSubmitting = false);
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat.yMMMd(locale);
    final installation = widget.installation;
    final isLate = installation.isLateAt(ref.watch(clockProvider)());
    final teamAsync = ref.watch(teamMembersProvider);
    final hasDeliveredItems = widget.order.perDelivered > 0;

    final statusLabel = isLate
        ? l10n.orderInstallationStatusOverdue
        : installation.status.localized(l10n);
    final statusIntent = isLate
        ? StatusIntent.danger
        : installation.status.intent;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.orderInstallationSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusChip(
                label: statusLabel,
                intent: statusIntent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_errorMessage != null) ...[
            _ErrorNotice(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (installation.status == OrderInstallationStatus.notScheduled) ...[
            if (!hasDeliveredItems) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: AppTint.ornamentOnDark,
                    ),
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
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.orderInstallationNoDeliveryNotice,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_isScheduling) ...[
              Text(
                l10n.orderInstallationReadyToSchedule,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => setState(() => _isScheduling = true),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.orderInstallationScheduleAction),
              ),
            ] else ...[
              teamAsync.when(
                data: (members) {
                  final selectable = members.where((m) => m.enabled).toList();
                  return DropdownButtonFormField<String>(
                    initialValue:
                        _selectedInstaller ?? selectable.firstOrNull?.email,
                    decoration: InputDecoration(
                      labelText: l10n.orderInstallationInstallerLabel,
                      prefixIcon: const Icon(AppIcons.profile),
                    ),
                    items: [
                      for (final m in selectable)
                        DropdownMenuItem(
                          value: m.email,
                          child: Text(
                            '${m.fullName} (${m.position.localizedName(l10n)})',
                          ),
                        ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedInstaller = val),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => TextFormField(
                  decoration: InputDecoration(
                    labelText: l10n.orderInstallationInstallerLabel,
                    prefixIcon: const Icon(AppIcons.profile),
                  ),
                  onChanged: (val) => _selectedInstaller = val,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.schedule),
                title: Text(l10n.orderInstallationDateLabel),
                subtitle: Text(
                  _installDate != null
                      ? date.format(_installDate!)
                      : l10n.orderInstallationDateRequired,
                  style: TextStyle(
                    color: _installDate == null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _pickInstallDate,
                  child: Text(l10n.enquiryFlowPickDeliveryDate),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _isScheduling = false),
                      child: Text(l10n.actionCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submitSchedule,
                      icon: _isSubmitting
                          ? const SizedBox.square(
                              dimension: AppIconSize.small,
                              child: CircularProgressIndicator(
                                strokeWidth: AppStroke.focus,
                              ),
                            )
                          : const Icon(AppIcons.check),
                      label: Text(l10n.orderInstallationScheduleAction),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (installation.status ==
              OrderInstallationStatus.scheduled) ...[
            if (installation.installer != null)
              _FieldRow(
                icon: AppIcons.profile,
                label:
                    '${l10n.orderInstallationInstallerLabel}: '
                    '${installation.installer}',
              ),
            if (installation.installDate != null)
              _FieldRow(
                icon: AppIcons.schedule,
                label:
                    '${l10n.orderInstallationDateLabel}: '
                    '${date.format(installation.installDate!)}',
                intent: isLate ? StatusIntent.danger : null,
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _showCompleteDialog,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: AppIconSize.small,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.focus,
                      ),
                    )
                  : const Icon(AppIcons.check),
              label: Text(l10n.orderInstallationCompleteAction),
            ),
          ] else if (installation.status ==
              OrderInstallationStatus.completed) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: AppTint.surface,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(
                    alpha: AppTint.ornamentOnDark,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.success,
                        color: theme.colorScheme.primary,
                        size: AppIconSize.normal,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.orderInstallationCompletedNotice,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (installation.installer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${l10n.orderInstallationInstallerLabel}: '
                      '${installation.installer}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (installation.installDate != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.orderInstallationDateLabel}: '
                      '${date.format(installation.installDate!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (installation.notes != null &&
                      installation.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            AppIcons.task,
                            size: AppIconSize.dense,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.orderInstallationNotesLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  installation.notes!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.icon, required this.label, this.intent});

  final IconData icon;
  final String label;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = intent == StatusIntent.danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.dense, color: colour),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(
          alpha: AppTint.surface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: theme.colorScheme.error.withValues(
            alpha: AppTint.ornamentOnDark,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.danger,
            color: theme.colorScheme.error,
            size: AppIconSize.small,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
