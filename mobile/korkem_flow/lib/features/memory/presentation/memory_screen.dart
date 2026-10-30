import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/memory/application/memory_controller.dart';
import 'package:korkem_flow/features/memory/domain/memory_fact.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying long-term assistant memory about the company and user.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(memoryControllerProvider);
    final controller = ref.read(memoryControllerProvider.notifier);

    return AppScreen(
      title: l10n.memoryTitle,
      subtitle: l10n.memorySubtitle,
      body: state.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: controller.refresh,
        ),
        data: (facts) {
          if (facts.isEmpty) {
            return ListEmptyView(
              icon: AppIcons.memory,
              title: l10n.memoryEmptyTitle,
              message: l10n.memoryEmptyBody,
              onRefresh: controller.refresh,
            );
          }

          final companyFacts = facts
              .where((f) => f.scope == MemoryScope.company)
              .toList(growable: false);
          final userFacts = facts
              .where((f) => f.scope == MemoryScope.user)
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SectionLabel(l10n.memorySectionCompany),
                if (companyFacts.isEmpty)
                  _EmptySectionCard(message: l10n.memoryEmptyCompany)
                else
                  for (final fact in companyFacts) ...[
                    _MemoryFactCard(fact: fact),
                    const SizedBox(height: AppSpacing.md),
                  ],
                const SizedBox(height: AppSpacing.xl),
                SectionLabel(l10n.memorySectionUser),
                if (userFacts.isEmpty)
                  _EmptySectionCard(message: l10n.memoryEmptyUser)
                else
                  for (final fact in userFacts) ...[
                    _MemoryFactCard(fact: fact),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _MemoryFactCard extends ConsumerStatefulWidget {
  const _MemoryFactCard({required this.fact});

  final MemoryFact fact;

  @override
  ConsumerState<_MemoryFactCard> createState() => _MemoryFactCardState();
}

class _MemoryFactCardState extends ConsumerState<_MemoryFactCard> {
  bool _busy = false;

  Future<void> _view(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fact = widget.fact;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          fact.scope == MemoryScope.company
              ? l10n.memorySectionCompany
              : l10n.memorySectionUser,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fact.text,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            StatusChip(
              label: fact.isConfirmed
                  ? l10n.memoryStatusConfirmed
                  : l10n.memoryStatusUnconfirmed,
              intent: fact.isConfirmed
                  ? StatusIntent.success
                  : StatusIntent.neutral,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.memorySourcePrefix(fact.sourceLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => _EditFactDialog(fact: widget.fact),
    );

    if (newText == null || newText == widget.fact.text) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(memoryControllerProvider.notifier)
          .updateFact(widget.fact.id, newText: newText);

      messenger.showDone(l10n.memoryFactUpdated);
    } on Exception catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await ref
          .read(memoryControllerProvider.notifier)
          .confirmFact(widget.fact.id);

      messenger.showDone(l10n.memoryFactConfirmed);
    } on Exception catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.memoryDeleteConfirmTitle,
      message: l10n.memoryDeleteConfirmBody,
      confirmLabel: l10n.memoryActionDelete,
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(memoryControllerProvider.notifier)
          .deleteFact(widget.fact.id);

      messenger.showDone(l10n.memoryFactDeleted);
    } on Exception catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fact = widget.fact;

    return AppCard(
      child: InkWell(
        onTap: () => _view(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      fact.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: fact.isConfirmed
                        ? l10n.memoryStatusConfirmed
                        : l10n.memoryStatusUnconfirmed,
                    intent: fact.isConfirmed
                        ? StatusIntent.success
                        : StatusIntent.neutral,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    AppIcons.info,
                    size: AppIconSize.dense,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      fact.sourceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: AppStroke.hairline),
              Row(
                children: [
                  if (!fact.isConfirmed) ...[
                    TextButton.icon(
                      onPressed: _busy ? null : () => _confirm(context),
                      icon: const Icon(
                        AppIcons.check,
                        size: AppIconSize.small,
                      ),
                      label: Text(l10n.memoryActionConfirm),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    icon: const Icon(
                      AppIcons.more,
                      size: AppIconSize.small,
                    ),
                    tooltip: l10n.memoryTitle,
                    onSelected: (action) async {
                      switch (action) {
                        case 'view':
                          await _view(context);
                        case 'edit':
                          await _edit(context);
                        case 'confirm':
                          await _confirm(context);
                        case 'delete':
                          await _delete(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            const Icon(
                              AppIcons.info,
                              size: AppIconSize.small,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l10n.memoryActionView),
                          ],
                        ),
                      ),
                      if (!fact.isConfirmed)
                        PopupMenuItem(
                          value: 'confirm',
                          child: Row(
                            children: [
                              const Icon(
                                AppIcons.check,
                                size: AppIconSize.small,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(l10n.memoryActionConfirm),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              AppIcons.edit,
                              size: AppIconSize.small,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l10n.memoryActionEdit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.delete,
                              size: AppIconSize.small,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              l10n.memoryActionDelete,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFactDialog extends StatefulWidget {
  const _EditFactDialog({required this.fact});

  final MemoryFact fact;

  @override
  State<_EditFactDialog> createState() => _EditFactDialogState();
}

class _EditFactDialogState extends State<_EditFactDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fact.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.memoryEditDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        decoration: InputDecoration(
          hintText: l10n.memoryEditHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.memoryActionSave),
        ),
      ],
    );
  }
}
