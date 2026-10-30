import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/notifications/data/notification_repository.dart';
import 'package:korkem_flow/features/notifications/domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(frappeClientProvider)),
);

/// Unread badge count.
///
/// Depends on the session, so signing in as someone else cannot leave the
/// previous user's number on screen.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(sessionProvider).value?.user;
  if (user == null) return 0;

  return ref.watch(notificationRepositoryProvider).unreadCount(user);
});

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, PagedList<AppNotification>>(
      NotificationsController.new,
    );

class NotificationsController extends PagedListController<AppNotification> {
  @override
  Future<List<AppNotification>> fetchPage({
    required int offset,
    required int pageSize,
  }) async {
    final user = ref.watch(sessionProvider).value?.user;
    // Never fall back to an unfiltered query: this doctype is readable by the
    // role `All` and Frappe applies no per-user scoping, so an empty filter
    // would return every user's notifications.
    if (user == null) return const [];

    return ref
        .watch(notificationRepositoryProvider)
        .fetchPage(forUser: user, pageSize: pageSize, offset: offset);
  }

  /// Marks one read, optimistically: the row is already on screen and the only
  /// visible effect is its own emphasis, so a rollback costs the user nothing.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: [
            for (final item in current.items)
              if (item.id == notification.id) item.asRead() else item,
          ],
        ),
      );
    }

    try {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
    } on Exception {
      if (current != null) state = AsyncData(current);
      rethrow;
    } finally {
      ref.invalidate(unreadNotificationsProvider);
    }
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(unreadNotificationsProvider);
    await refresh();
  }
}
