import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/team/domain/team_moves.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';

final teamStructureRepositoryProvider = Provider<TeamStructureRepository>(
  (ref) => TeamStructureRepository(ref.watch(frappeClientProvider)),
);

/// Everyone at the company in one list, the departed too — «Команда» and its
/// people are one thing (owner, 17.11.2026).
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

  Future<TeamPeople> people() async => TeamPeople.fromJson(
    _map(
      await _client.callMethod(
        '$_base.people',
        params: {'include_left': 1},
      ),
    ),
  );

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

  /// What is sent changes. A login with no person yet becomes one.
  Future<TeamPeople> change(
    TeamPerson person, {
    String? name,
    List<String>? posts,
    String? phone,
  }) => _post('set_person', {
    'employee': ?person.employee,
    if (person.employee == null) 'user': ?person.user,
    'name': ?name,
    if (posts != null) 'posts': jsonEncode(posts),
    'phone': ?phone,
  });

  /// Left the company: off the list, his work stays his; back again.
  Future<TeamPeople> setActive(TeamPerson person, {required bool active}) =>
      _post('set_active', {
        'employee': ?person.employee,
        if (person.employee == null) 'user': ?person.user,
        'active': active ? 1 : 0,
      });

  /// His login, so he sees his own orders from his phone; null unlinks.
  Future<TeamPeople> linkUser(String employee, String? user) =>
      _post('link_user', {'employee': employee, 'user': user ?? ''});

  /// One post given ([on]) or taken — against what the server holds now.
  Future<TeamPeople> setPost(
    TeamPerson person,
    String post, {
    required bool on,
  }) => _post('set_post', {
    'post': post,
    'on': on ? 1 : 0,
    'employee': ?person.employee,
    if (person.employee == null) 'user': ?person.user,
  });

  /// Stages given to him and not yet done; of [post] only, if given.
  Future<List<TeamOpenWork>> openWork(String employee, {String? post}) async =>
      [
        for (final w in _list(
          await _client.callMethod(
            '$_base.open_work',
            params: {'employee': employee, 'post': ?post},
          ),
        ))
          TeamOpenWork.fromJson(w),
      ];

  /// His open stages (of [post]) to [to] — or to nobody. How many moved.
  Future<int> handOver(String employee, {String? to, String? post}) async {
    final r = _map(
      await _client.callMethod(
        '$_base.hand_over',
        post: true,
        params: {'employee': employee, 'to': ?to, 'post': ?post},
      ),
    );
    return r['moved'] is num ? (r['moved'] as num).toInt() : 0;
  }

  /// Before «Уволен»: what is open and what is owed.
  Future<TeamDismissal> dismissal(String employee) async =>
      TeamDismissal.fromJson(
        _map(
          await _client.callMethod(
            '$_base.dismissal',
            params: {'employee': employee},
          ),
        ),
      );

  /// Already on the list with this name or phone — the departed too.
  Future<List<TeamDuplicate>> duplicates(String name, String? phone) async => [
    for (final d in _list(
      await _client.callMethod(
        '$_base.duplicates',
        params: {'name': name, 'phone': ?phone},
      ),
    ))
      TeamDuplicate.fromJson(d),
  ];

  List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! List) {
      throw const ServerFailure('Сервер не ответил по команде.');
    }
    return [
      for (final r in raw)
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }

  Future<TeamPeople> _post(String method, Map<String, dynamic> params) async =>
      TeamPeople.fromJson(
        _map(
          await _client.callMethod(
            '$_base.$method',
            post: true,
            params: params,
          ),
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
