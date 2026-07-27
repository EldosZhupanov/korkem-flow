import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/tasks/application/tasks_controller.dart';
import 'package:korkem_flow/features/tasks/domain/task.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The worker-facing surface: everything assigned, grouped by urgency.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(groupedTasksProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTasks)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(tasksControllerProvider.notifier).refresh(),
        child: switch (grouped) {
          AsyncLoading() => const ListSkeleton(),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.read(tasksControllerProvider.notifier).refresh(),
          ),
          AsyncData(:final value) when value.isEmpty => EmptyView(
            icon: AppIcons.task,
            title: l10n.tasksEmpty,
            message: l10n.tasksEmptyBody,
          ),
          AsyncData(:final value) => _TaskGroupList(groups: value),
        },
      ),
    );
  }
}

class _TaskGroupList extends StatelessWidget {
  const _TaskGroupList({required this.groups});

  final TaskGroups groups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Section(
          label: l10n.tasksOverdue,
          intent: StatusIntent.danger,
          tasks: groups.overdue,
        ),
        _Section(
          label: l10n.tasksToday,
          intent: StatusIntent.warning,
          tasks: groups.today,
        ),
        _Section(
          label: l10n.tasksUpcoming,
          intent: StatusIntent.neutral,
          tasks: groups.upcoming,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.intent,
    required this.tasks,
  });

  final String label;
  final StatusIntent intent;
  final List<WorkTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.statusColors.resolve(intent),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${tasks.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: TaskCard(task: task),
          ),
      ],
    );
  }
}

/// A single task, completable in one swipe or one tap.
///
/// Completion is irreversible from the app's side, so it is confirmed by an
/// undoable snackbar rather than a blocking dialog — reversible feedback beats
/// a modal for an action performed dozens of times a shift.
class TaskCard extends ConsumerWidget {
  const TaskCard({required this.task, super.key});

  final WorkTask task;

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(tasksControllerProvider.notifier).complete(task);
      messenger.showSnackBar(SnackBar(content: Text(l10n.taskCompleted)));
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final due = task.dueDate;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.statusColors.success.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(AppIcons.check, color: context.statusColors.success),
      ),
      onDismissed: (_) => _complete(context, ref),
      child: EntityCard(
        title: task.title,
        statusLabel: task.isOverdue ? l10n.tasksOverdue : null,
        statusIntent: task.isOverdue ? StatusIntent.danger : null,
        metadata: [
          if (task.isProduction)
            EntityMeta(icon: AppIcons.workOrder, label: l10n.taskProduction),
          if (due != null)
            EntityMeta(
              icon: AppIcons.warning,
              label: DateFormat.MMMd(
                Localizations.localeOf(context).languageCode,
              ).add_Hm().format(due),
            ),
          if (task.assignedTo != null)
            EntityMeta(icon: AppIcons.profile, label: task.assignedTo!),
        ],
        leading: IconButton(
          icon: const Icon(AppIcons.success),
          iconSize: AppIconSize.normal,
          color: theme.colorScheme.outline,
          tooltip: l10n.taskComplete,
          onPressed: () => _complete(context, ref),
        ),
      ),
    );
  }
}
