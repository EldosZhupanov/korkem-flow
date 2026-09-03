import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final teamPositionsProvider = FutureProvider.autoDispose<List<PositionOption>>((
  ref,
) async {
  final repo = ref.watch(teamRepositoryProvider);
  return repo.fetchPositions();
});

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
  // Один вопрос — один ответ сервера. Раньше это выводили здесь: брали список
  // команды, искали себя, смотрели роли. Роли клиенту не видны, поэтому
  // владелец не узнавал сам себя и оставался без кнопки «Пригласить».
  final session = ref.watch(sessionProvider).value;
  if (!(session?.isAuthenticated ?? false)) return false;

  return ref.read(teamRepositoryProvider).canInvite();
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
    required String position,
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
