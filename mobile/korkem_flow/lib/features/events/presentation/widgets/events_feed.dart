import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/events/application/events_controller.dart';
import 'package:korkem_flow/features/events/domain/proactive_event.dart';
import 'package:korkem_flow/features/events/presentation/widgets/event_card.dart';
import 'package:korkem_flow/features/production/data/production_command_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The proactive events feed displayed at the top of the "Today" screen.
///
/// If empty, it renders an reassuring "all clear" message rather than an empty
/// state or generic placeholder.
class EventsFeed extends ConsumerWidget {
  const EventsFeed({
    this.onAction,
    this.onDismiss,
    this.showEmptyClear = true,
    super.key,
  });

  /// Optional override for action button execution.
  final void Function(ProactiveEvent event, EventAction action)? onAction;

  /// Optional callback after an event is dismissed.
  final void Function(ProactiveEvent event)? onDismiss;

  /// Whether to render the all-clear state when the events list is empty.
  final bool showEmptyClear;

  Future<void> _handleDefaultAction(
    BuildContext context,
    WidgetRef ref,
    ProactiveEvent event,
    EventAction action,
  ) async {
    if (onAction != null) {
      onAction!(event, action);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (action.id == 'start' && event.subject?.doctype == 'Sales Order') {
      try {
        final result = await ref
            .read(productionCommandRepositoryProvider)
            .start(event.subject!.name);
        if (result.started) {
          messenger.showDone(l10n.ordersStartSuccess(event.subject!.name));
          await ref.read(eventsControllerProvider.notifier).dismiss(event.id);
        } else {
          messenger.showFailureMessage(
            result.message ?? l10n.ordersBlockedSummary(event.subject!.name),
          );
        }
      } on Object catch (e) {
        messenger.showFailure(e, l10n);
      }
      return;
    }

    // Default fallback: navigate to the subject route if available
    final route = event.subject?.route;
    if (route != null) {
      unawaited(context.push(route));
    }
  }

  Future<void> _handleDismiss(
    BuildContext context,
    WidgetRef ref,
    ProactiveEvent event,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(eventsControllerProvider.notifier).dismiss(event.id);
      messenger.showDone(l10n.eventsDismissSuccess);
      onDismiss?.call(event);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventsControllerProvider);

    return state.when(
      loading: () => const ListSkeleton(rows: 1),
      // Одной строкой, а не полным экраном отказа. Когда связи нет, не грузится
      // и сводка — два одинаковых блока с двумя кнопками «Повторить» об одной
      // и той же причине читаются как две поломки вместо одной.
      error: (err, _) => _EventsUnavailable(
        onRetry: () => ref.read(eventsControllerProvider.notifier).refresh(),
      ),
      data: (events) {
        if (events.isEmpty) {
          if (!showEmptyClear) return const SizedBox.shrink();
          return const EventsAllClearCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: EventCard(
                  event: event,
                  onDismiss: () =>
                      unawaited(_handleDismiss(context, ref, event)),
                  onAction: (action) => unawaited(
                    _handleDefaultAction(context, ref, event, action),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Лента не загрузилась. Это не главная новость экрана, и выглядит она так.
class _EventsUnavailable extends StatelessWidget {
  const _EventsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Icon(
          AppIcons.warning,
          size: AppIconSize.dense,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            l10n.eventsLoadFailed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
      ],
    );
  }
}

/// A card that communicates calm and control when there are no urgent issues.
class EventsAllClearCard extends StatelessWidget {
  const EventsAllClearCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final successColor = context.statusColors.success;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: AppTouchTarget.min,
            height: AppTouchTarget.min,
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: AppTint.surface),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.success,
              color: successColor,
              size: AppIconSize.normal,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eventsAllClearTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.eventsAllClearDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
