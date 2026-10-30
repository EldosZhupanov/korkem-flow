import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/operations/data/operations_repository.dart';
import 'package:korkem_flow/features/operations/domain/delivery.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What the system told people, and what it could not.
///
/// Named for deliveries rather than notifications because the app already has a
/// notifications screen — that one is what *this user* was told, and this is
/// the operator's view of every message the system tried to send to anybody.
///
/// The screen exists because "the foreman never heard" is a question somebody
/// asks out loud, and the honest answer lives in a table nobody outside the
/// desk can read. It shows the delivery record and offers the two actions an
/// administrator actually has: try again, or stop trying.
///
/// **No credential and no third-party conversation.** The body shown here is
/// the notification this system composed — the thing being judged — and never a
/// customer's own words, which live under the conversation's permission.
class DeliveryCentreScreen extends ConsumerStatefulWidget {
  const DeliveryCentreScreen({super.key});

  @override
  ConsumerState<DeliveryCentreScreen> createState() =>
      _DeliveryCentreScreenState();
}

class _DeliveryCentreScreenState extends ConsumerState<DeliveryCentreScreen> {
  /// Which chip is selected is view state: it belongs to this screen and
  /// nowhere else.
  String _filter = allStates;
  bool _busy = false;

  static const List<String> _filters = [
    allStates,
    NotificationDelivery.pending,
    NotificationDelivery.sent,
    NotificationDelivery.retrying,
    NotificationDelivery.failed,
    NotificationDelivery.deadLetter,
  ];

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(deliveriesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(deliveriesProvider(_filter));

    return AppScreen(
      title: l10n.notificationsTitle,
      subtitle: l10n.notificationsSubtitle,
      actions: [
        TextButton(
          key: const ValueKey('retryAll'),
          onPressed: _busy
              ? null
              : () => _run(
                  () async => ref.read(operationsRepositoryProvider).retryAll(),
                ),
          child: Text(l10n.notificationsRetryAll),
        ),
      ],
      body: board.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(deliveriesProvider),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  for (final filter in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        key: ValueKey('filter:$filter'),
                        label: Text(
                          filter == allStates
                              ? l10n.notificationsFilterAll
                              : '$filter ${data.summary[filter] ?? 0}',
                        ),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: data.deliveries.isEmpty
                  ? Center(child: Text(l10n.notificationsEmpty))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: data.deliveries.length,
                      itemBuilder: (context, index) => _DeliveryTile(
                        delivery: data.deliveries[index],
                        busy: _busy,
                        onRetry: () => _run(
                          () async => ref
                              .read(operationsRepositoryProvider)
                              .retry(data.deliveries[index].name),
                        ),
                        onCancel: () => _run(
                          () async => ref
                              .read(operationsRepositoryProvider)
                              .cancel(data.deliveries[index].name),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({
    required this.delivery,
    required this.busy,
    required this.onRetry,
    required this.onCancel,
  });

  final NotificationDelivery delivery;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  Color _colour(BuildContext context) => switch (delivery.status) {
    NotificationDelivery.sent => context.statusColors.success,
    NotificationDelivery.failed ||
    NotificationDelivery.deadLetter => context.statusColors.danger,
    NotificationDelivery.retrying => context.statusColors.warning,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: ExpansionTile(
        key: ValueKey('delivery:${delivery.name}'),
        title: Text(delivery.event, style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${delivery.recipient} · ${delivery.channel ?? ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          delivery.status,
          style: theme.textTheme.labelSmall?.copyWith(color: _colour(context)),
        ),
        childrenPadding: const EdgeInsets.all(AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (delivery.body != null) Text(delivery.body!),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.notificationsAttempts}: ${delivery.attempts}',
            style: theme.textTheme.bodySmall,
          ),
          if (delivery.nextAttemptAt != null)
            Text(
              '${l10n.notificationsNextAttempt}: ${delivery.nextAttemptAt}',
              style: theme.textTheme.bodySmall,
            ),
          if (delivery.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                delivery.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.statusColors.danger,
                ),
              ),
            ),
          if (delivery.eventKey != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SelectableText(
                delivery.eventKey!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (delivery.canCancel)
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: Text(l10n.notificationsCancel),
                ),
              if (delivery.canRetry)
                FilledButton(
                  key: ValueKey('retry:${delivery.name}'),
                  onPressed: busy ? null : onRetry,
                  child: Text(l10n.notificationsRetry),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
