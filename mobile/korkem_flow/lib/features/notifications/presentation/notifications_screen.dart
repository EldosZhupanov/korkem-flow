import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navNotifications),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: PagedListView<AppNotification>(
        state: ref.watch(notificationsControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, notification) =>
            NotificationCard(notification: notification),
        emptyView: (context) => EmptyView(
          icon: AppIcons.success,
          title: l10n.notificationsEmpty,
          message: l10n.notificationsEmptyBody,
        ),
      ),
    );
  }
}

class NotificationCard extends ConsumerWidget {
  const NotificationCard({required this.notification, super.key});

  final AppNotification notification;

  /// Opens the record the notification is about, when the app has a screen for
  /// its doctype. Frappe notifies about far more doctypes than this app shows,
  /// so an unmapped one stays unopenable rather than routing somewhere wrong.
  String? _destination() {
    final name = notification.documentName;
    if (name == null) return null;

    return switch (notification.documentType) {
      'CRM Deal' => Routes.deal(name),
      'CRM Lead' => Routes.lead(name),
      'CRM Organization' => Routes.customer(name),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final destination = _destination();
    final created = notification.createdAt;

    return AppCard(
      onTap: () async {
        final router = GoRouter.of(context);
        await ref
            .read(notificationsControllerProvider.notifier)
            .markRead(notification);
        // Router captured before the await: opening the record must not depend
        // on this element still being mounted after the round trip.
        if (destination != null) unawaited(router.push<void>(destination));
      },
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
              padding: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
