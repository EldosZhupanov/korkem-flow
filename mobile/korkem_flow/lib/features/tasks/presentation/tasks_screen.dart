import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/motion/swipe_action.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
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

    final controller = ref.read(tasksControllerProvider.notifier);

    // A deferred completion fails long after the swipe that started it, with
    // no `await` left to throw into. This is where it surfaces.
    ref.listen(taskFailureProvider, (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(
        context,
      ).showFailureMessage(
        l10n.taskCompleteFailed(errorMessageOf(failure, l10n)),
      );
      ref.read(taskFailureProvider.notifier).clear();
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTasks)),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: switch (grouped) {
          AsyncLoading() => const ListSkeleton(),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: controller.refresh,
          ),
          // Offers refresh like every other list in the app. Pull-to-refresh
          // works here too and always has, but it is invisible, and an empty
          // screen is exactly when a user decides the app is broken.
          AsyncData(:final value) when value.isEmpty => ListEmptyView(
            icon: AppIcons.task,
            tone: StateTone.success,
            title: l10n.tasksEmpty,
            message: l10n.tasksEmptyBody,
            onRefresh: controller.refresh,
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
                style: AppTypography.overline(
                  (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: context.statusColors.resolve(intent),
                  ),
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
/// Confirmed by a snackbar offering **Undo** rather than by a blocking dialog.
/// A worker completes dozens of these a shift and a modal in front of every
/// one is a tax; a way back afterwards costs nothing until it is needed.
///
/// The undo is real, not cosmetic: the request is held for its whole window
/// (see `TasksController.completeLater`), so undoing cancels something that
/// was never sent. `CRM Task` has no reopen call, and offering an undo that
/// could not actually undo would be worse than offering none.
class TaskCard extends ConsumerStatefulWidget {
  const TaskCard({required this.task, super.key});

  final WorkTask task;

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  /// How far through the swipe the finger is, 0 to 1.
  double _progress = 0;

  void _complete() {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(tasksControllerProvider.notifier);
    final task = widget.task;

    controller.completeLater(task);

    ScaffoldMessenger.of(context).showUndoable(
      message: l10n.taskCompleted,
      undoLabel: l10n.actionUndo,
      onUndo: () => controller.undoComplete(task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final task = widget.task;
    final due = task.dueDate;
    final success = context.statusColors.success;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.startToEnd,
      onUpdate: (details) {
        if (details.progress != _progress) {
          setState(() => _progress = details.progress);
        }
      },
      background: SwipeActionBackground(
        icon: AppIcons.check,
        color: success,
        progress: _progress,
      ),
      onDismissed: (_) => _complete(),
      child: EntityCard(
        title: task.title,
        // Priority, not overdue-ness: the red section header above already says
        // "overdue", and repeating it here bought nothing while costing the
        // title half a line. Priority is shown nowhere else, and only the
        // exceptional value earns a chip — a list where every row is badged
        // is a list with no signal.
        statusLabel: task.priority == TaskPriority.high
            ? l10n.taskPriorityHigh
            : null,
        statusIntent: task.priority == TaskPriority.high
            ? StatusIntent.warning
            : null,
        // Task titles are sentences, not names, and need the whole width.
        statusPlacement: StatusPlacement.metadata,
        metadata: [
          if (task.isProduction)
            EntityMeta(icon: AppIcons.workOrder, label: l10n.taskProduction),
          if (due != null)
            EntityMeta(
              icon: AppIcons.schedule,
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
          onPressed: _complete,
        ),
      ),
    );
  }
}
