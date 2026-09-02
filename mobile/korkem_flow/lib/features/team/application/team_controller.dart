import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((
  ref,
) async {
  final repo = ref.watch(teamRepositoryProvider);
  return repo.fetchTeamMembers();
});

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final canInviteProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(sessionProvider).value;
  final currentUser = session?.user?.trim().toLowerCase();
  if (currentUser == null) return false;
  if (currentUser == 'administrator') return true;

  final members = await ref.watch(teamMembersProvider.future);
  final current = members
      .where((m) => m.email.trim().toLowerCase() == currentUser)
      .firstOrNull;

  if (current != null) {
    return current.isOwner;
  }
  // If no members are loaded yet or current user is the only user
  return true;
});

final teamInviteControllerProvider =
    AsyncNotifierProvider<TeamInviteController, TeamInviteResult?>(
      TeamInviteController.new,
    );

class TeamInviteController extends AsyncNotifier<TeamInviteResult?> {
  @override
  Future<TeamInviteResult?> build() async => null;

  Future<TeamInviteResult> invite({
    required String email,
    required EmployeePosition position,
    String firstName = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(teamRepositoryProvider);
      final result = await repo.inviteEmployee(
        email: email,
        position: position,
        firstName: firstName,
      );
      state = AsyncValue.data(result);
      ref.invalidate(teamMembersProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
