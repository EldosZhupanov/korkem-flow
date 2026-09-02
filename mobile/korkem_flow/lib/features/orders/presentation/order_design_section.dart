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
import 'package:korkem_flow/features/orders/application/order_design_controller.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Stage 5 Design section displayed on the Sales Order detail screen.
class OrderDesignSection extends ConsumerWidget {
  const OrderDesignSection({required this.order, super.key});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designAsync = ref.watch(orderDesignProvider(order.name));

    return switch (designAsync) {
      AsyncData(:final value) => _DesignCard(order: order, design: value),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(orderDesignProvider(order.name)),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _DesignCard extends ConsumerStatefulWidget {
  const _DesignCard({required this.order, required this.design});

  final SalesOrder order;
  final OrderDesign design;

  @override
  ConsumerState<_DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends ConsumerState<_DesignCard> {
  bool _isAssigning = false;
  String? _selectedDesigner;
  DateTime? _dueDate;
  String? _errorMessage;
  bool _isSubmitting = false;

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitAssign() async {
    final l10n = AppLocalizations.of(context);
    var designer = _selectedDesigner;
    if (designer == null || designer.trim().isEmpty) {
      final team = ref.read(teamMembersProvider).value;
      designer = team?.where((m) => m.enabled).firstOrNull?.email;
    }
    if (designer == null || designer.trim().isEmpty) {
      setState(() => _errorMessage = l10n.orderDesignDesignerLabel);
      return;
    }
    if (_dueDate == null) {
      setState(() => _errorMessage = l10n.orderDesignDueDateRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final dateStr =
        '${_dueDate!.year}-'
        '${_dueDate!.month.toString().padLeft(2, '0')}-'
        '${_dueDate!.day.toString().padLeft(2, '0')}';

    try {
      await ref
          .read(orderDesignActionsProvider)
          .assign(
            salesOrder: widget.order.name,
            designer: designer,
            dueOn: dateStr,
          );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isAssigning = false;
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

  Future<void> _submitDeliver() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(orderDesignActionsProvider)
          .deliver(
            salesOrder: widget.order.name,
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

  Future<void> _showAttachDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: 'чертёж_${widget.order.name}.dxf',
    );
    final urlController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.orderDesignAttachDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.orderDesignFileNameLabel,
                hintText: l10n.orderDesignFileNameHint,
                prefixIcon: const Icon(AppIcons.attachment),
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL / Ссылка (опционально)',
                prefixIcon: Icon(AppIcons.share),
              ),
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
            icon: const Icon(AppIcons.attachment),
            label: Text(l10n.orderDesignAttachButton),
          ),
        ],
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        await ref
            .read(orderDesignActionsProvider)
            .attachFile(
              salesOrder: widget.order.name,
              fileName: nameController.text.trim(),
              fileUrl: urlController.text.trim(),
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
    final design = widget.design;
    final isLate = design.isLateAt(ref.watch(clockProvider)());
    final teamAsync = ref.watch(teamMembersProvider);

    final statusLabel = isLate
        ? l10n.orderDesignStatusOverdue
        : design.status.localized(l10n);
    final statusIntent = isLate ? StatusIntent.danger : design.status.intent;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.orderDesignSection,
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
          if (design.status == OrderDesignStatus.notAssigned) ...[
            if (!_isAssigning) ...[
              Text(
                l10n.orderDesignNoTaskBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => setState(() => _isAssigning = true),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.orderDesignAssignAction),
              ),
            ] else ...[
              teamAsync.when(
                data: (members) {
                  final selectable = members.where((m) => m.enabled).toList();
                  return DropdownButtonFormField<String>(
                    initialValue:
                        _selectedDesigner ?? selectable.firstOrNull?.email,
                    decoration: InputDecoration(
                      labelText: l10n.orderDesignDesignerLabel,
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
                    onChanged: (val) => setState(() => _selectedDesigner = val),
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
                    labelText: l10n.orderDesignDesignerLabel,
                    prefixIcon: const Icon(AppIcons.profile),
                  ),
                  onChanged: (val) => _selectedDesigner = val,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.schedule),
                title: Text(l10n.orderDesignDueDateLabel),
                subtitle: Text(
                  _dueDate != null
                      ? date.format(_dueDate!)
                      : l10n.orderDesignDueDateRequired,
                  style: TextStyle(
                    color: _dueDate == null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _pickDueDate,
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
                          : () => setState(() => _isAssigning = false),
                      child: Text(l10n.actionCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submitAssign,
                      icon: _isSubmitting
                          ? const SizedBox.square(
                              dimension: AppIconSize.small,
                              child: CircularProgressIndicator(
                                strokeWidth: AppStroke.focus,
                              ),
                            )
                          : const Icon(AppIcons.check),
                      label: Text(l10n.orderDesignAssignAction),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (design.status == OrderDesignStatus.assigned) ...[
            if (design.designer != null)
              _FieldRow(
                icon: AppIcons.profile,
                label: '${l10n.orderDesignDesignerLabel}: ${design.designer}',
              ),
            if (design.dueDate != null)
              _FieldRow(
                icon: AppIcons.schedule,
                label:
                    '${l10n.orderDesignDueDateLabel}: '
                    '${date.format(design.dueDate!)}',
                intent: isLate ? StatusIntent.danger : null,
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.orderDesignFilesHeader} (${design.fileCount})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showAttachDialog,
                  icon: const Icon(
                    AppIcons.attachment,
                    size: AppIconSize.dense,
                  ),
                  label: Text(l10n.orderDesignAttachFileAction),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (design.attachments.isEmpty)
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
                        l10n.orderDesignNoFilesNotice,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final att in design.attachments)
                _AttachmentTile(attachment: att),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitDeliver,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: AppIconSize.small,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.focus,
                      ),
                    )
                  : const Icon(AppIcons.check),
              label: Text(l10n.orderDesignDeliverAction),
            ),
          ] else if (design.status == OrderDesignStatus.delivered) ...[
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
                        l10n.orderDesignCompletedNotice,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (design.designer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${l10n.orderDesignDesignerLabel}: ${design.designer}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (design.dueDate != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.orderDesignDueDateLabel}: '
                      '${date.format(design.dueDate!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${l10n.orderDesignFilesHeader} (${design.fileCount}):',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final att in design.attachments)
                    _AttachmentTile(attachment: att),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _showAttachDialog,
                    icon: const Icon(
                      AppIcons.attachment,
                      size: AppIconSize.dense,
                    ),
                    label: Text(l10n.orderDesignAttachFileAction),
                  ),
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

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final OrderDesignAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.attachment, size: AppIconSize.dense),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              attachment.fileName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
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
