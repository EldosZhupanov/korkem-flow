import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/motion/swipe_action.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/notifications/application/notifications_controller.dart';
import 'package:korkem_flow/features/notifications/domain/app_notification.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;

    return AppScreen(
      title: l10n.navNotifications,
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: controller.markAllRead,
            child: Text(l10n.notificationsMarkAllRead),
          ),
      ],
      body: PagedListView<AppNotification>(
        state: ref.watch(notificationsControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, notification) =>
            NotificationCard(notification: notification),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.success,
          tone: StateTone.success,
          title: l10n.notificationsEmpty,
          message: l10n.notificationsEmptyBody,
          onRefresh: controller.refresh,
        ),
      ),
    );
  }
}

class NotificationCard extends ConsumerStatefulWidget {
  const NotificationCard({required this.notification, super.key});

  final AppNotification notification;

  @override
  ConsumerState<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<NotificationCard> {
  /// How far through the swipe the finger is, 0 to 1.
  double _progress = 0;

  /// Opens the record the notification is about, when the app has a screen for
  /// its doctype. Frappe notifies about far more doctypes than this app shows,
  /// so an unmapped one stays unopenable rather than routing somewhere wrong.
  String? _destination() {
    final name = widget.notification.documentName;
    if (name == null) return null;

    return switch (widget.notification.documentType) {
      'CRM Deal' => Routes.deal(name),
      'CRM Lead' => Routes.lead(name),
      'CRM Organization' => Routes.customer(name),
      _ => null,
    };
  }

  Future<void> _markRead() => ref
      .read(notificationsControllerProvider.notifier)
      .markRead(widget.notification);

  Future<void> _open() async {
    // Captured before the await: opening the record must not depend on this
    // element still being mounted after the round trip.
    final router = GoRouter.of(context);
    final destination = _destination();

    try {
      await _markRead();
    } on Exception {
      // Marking read is the lesser half of this tap. Letting a failed write
      // abort the navigation meant a notification could not be opened at all
      // whenever the network was poor — which is exactly when someone is most
      // likely to be chasing it. The dot stays; the record still opens.
    }

    if (destination != null) unawaited(router.push<void>(destination));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final notification = widget.notification;
    final created = notification.createdAt;

    final card = AppCard(
      onTap: _open,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread is carried by a filled dot and by weight, never by colour
          // alone — the same rule the status chips follow.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(
              notification.type.icon,
              size: AppIconSize.small,
              color: notification.isRead
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.subject,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: notification.isRead
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (created != null)
                      Text(
                        DateFormat.MMMd(locale).add_Hm().format(created),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    if (notification.documentName != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          notification.documentName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                // Centres the dot on the first line of the subject rather than
                // on the block of text, which on a two-line subject would sit
                // it halfway down the row.
                top: AppIndicator.dotBaselineOffset,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: AppIndicator.dot),
              ),
            ),
        ],
      ),
    );

    // Nothing to do to a notification that is already read, so the gesture is
    // switched off rather than left to run and achieve nothing.
    if (notification.isRead) return card;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.startToEnd,
      onUpdate: (details) {
        if (details.progress != _progress) {
          setState(() => _progress = details.progress);
        }
      },
      // Always false: the row is not going anywhere. Marking read changes only
      // its own emphasis, and dropping it out of the list would hide a record
      // the user may well still want to open — the swipe is a way to clear the
      // badge, not to discard the notice.
      confirmDismiss: (_) async {
        try {
          await _markRead();
        } on Exception {
          // The controller already rolls the row back to unread; a snackbar
          // for a failed badge update would cost more attention than the
          // badge is worth.
        }
        return false;
      },
      background: SwipeActionBackground(
        icon: AppIcons.check,
        color: Theme.of(context).colorScheme.primary,
        progress: _progress,
      ),
      child: card,
    );
  }
}
