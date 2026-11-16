import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';

final teamStructureRepositoryProvider = Provider<TeamStructureRepository>(
  (ref) => TeamStructureRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final teamPeopleProvider = FutureProvider.autoDispose<TeamPeople>(
  (ref) => ref.watch(teamStructureRepositoryProvider).people(),
);

/// Departments, posts and the people on them (owner, 17.11.2026).
class TeamStructureRepository {
  TeamStructureRepository(this._client);

  final FrappeClient _client;

  static const _base = 'korkem_manufacturing.api.team';

  Future<TeamPeople> people() async =>
      TeamPeople.fromJson(_map(await _client.callMethod('$_base.people')));

  /// A person with no login: the manager ticks for him.
  Future<TeamPeople> add({
    required String name,
    required List<String> posts,
    String? phone,
  }) => _post('add_person', {
    'name': name,
    'posts': jsonEncode(posts),
    'phone': ?phone,
  });

  /// What is sent changes.
  Future<TeamPeople> change(
    String employee, {
    String? name,
    List<String>? posts,
    String? phone,
  }) => _post('set_person', {
    'employee': employee,
    'name': ?name,
    if (posts != null) 'posts': jsonEncode(posts),
    'phone': ?phone,
  });

  /// Left the company: off the list, his work stays his.
  Future<TeamPeople> setActive(String employee, {required bool active}) =>
      _post('set_active', {'employee': employee, 'active': active ? 1 : 0});

  /// His login, so he sees his own orders from his phone; null unlinks.
  Future<TeamPeople> linkUser(String employee, String? user) =>
      _post('link_user', {'employee': employee, 'user': user ?? ''});

  Future<TeamPeople> _post(String method, Map<String, dynamic> params) async =>
      TeamPeople.fromJson(
        _map(
          await _client.callMethod('$_base.$method', post: true, params: params),
        ),
      );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по команде.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
