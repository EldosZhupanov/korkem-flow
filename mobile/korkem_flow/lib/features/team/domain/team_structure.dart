import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/phone/phone.dart';

/// One post in a department: «Шкурщик» in «Покраска», key `paint.sander`.
/// [stages] — the order stages it does (sand), none for the film seller.
@immutable
class TeamPost {
  const TeamPost({
    required this.key,
    required this.title,
    this.stages = const [],
  });

  factory TeamPost.fromJson(Map<String, dynamic> json) => TeamPost(
    key: '${json['key']}',
    title: '${json['title'] ?? json['key']}',
    stages: [for (final s in json['stages'] as List? ?? const []) '$s'],
  );

  final String key;
  final String title;
  final List<String> stages;
}

/// A department and its posts, in the shop's order.
@immutable
class TeamDepartment {
  const TeamDepartment({
    required this.key,
    required this.title,
    required this.posts,
  });

  factory TeamDepartment.fromJson(Map<String, dynamic> json) => TeamDepartment(
    key: '${json['key']}',
    title: '${json['title'] ?? json['key']}',
    posts: [
      for (final p in json['posts'] as List? ?? const [])
        if (p is Map) TeamPost.fromJson(Map<String, dynamic>.from(p)),
    ],
  );

  final String key;
  final String title;
  final List<TeamPost> posts;
}

/// A person's login: what the program lets him do ([position]), and whether
/// it is open. A mark on the person, not a second list (owner, 17.11.2026:
/// «команда и люди одно и то же»).
@immutable
class TeamLogin {
  const TeamLogin({
    required this.user,
    required this.position,
    this.enabled = true,
    this.isOwner = false,
  });

  factory TeamLogin.fromJson(Map<String, dynamic> json) => TeamLogin(
    user: '${json['user']}',
    position: '${json['position'] ?? ''}',
    enabled: json['enabled'] != false,
    isOwner: json['is_owner'] == true,
  );

  final String user;
  final String position;
  final bool enabled;
  final bool isOwner;
}

/// A person at the company — with or without a login ([user]). [employee]
/// is null for a login from before the team had people: he becomes one the
/// first time he is changed.
@immutable
class TeamPerson {
  const TeamPerson({
    required this.employee,
    required this.name,
    this.phone,
    this.user,
    this.login,
    this.active = true,
    this.posts = const [],
    this.inWork = 0,
  });

  factory TeamPerson.fromJson(Map<String, dynamic> json) => TeamPerson(
    employee: json['employee'] == null || '${json['employee']}'.isEmpty
        ? null
        : '${json['employee']}',
    name: '${json['name'] ?? json['employee'] ?? json['user']}',
    phone: json['phone'] == null || '${json['phone']}'.isEmpty
        ? null
        : Phone.pretty('${json['phone']}'),
    user: json['user'] == null || '${json['user']}'.isEmpty
        ? null
        : '${json['user']}',
    login: json['login'] is Map
        ? TeamLogin.fromJson(Map<String, dynamic>.from(json['login'] as Map))
        : null,
    active: json['active'] != false,
    posts: [for (final p in json['posts'] as List? ?? const []) '$p'],
    inWork: json['in_work'] is num ? (json['in_work'] as num).toInt() : 0,
  );

  final String? employee;
  final String name;
  final String? phone;
  final String? user;
  final TeamLogin? login;
  final bool active;
  final List<String> posts;

  /// Open order stages given to him.
  final int inWork;

  /// One key per person, with or without an employee record.
  String get id => employee ?? 'user:$user';
}

/// The departments, their posts and the people on them.
@immutable
class TeamPeople {
  const TeamPeople({
    required this.departments,
    required this.people,
    this.canEdit = false,
  });

  factory TeamPeople.fromJson(Map<String, dynamic> json) => TeamPeople(
    departments: [
      for (final d in json['departments'] as List? ?? const [])
        if (d is Map) TeamDepartment.fromJson(Map<String, dynamic>.from(d)),
    ],
    people: [
      for (final p in json['people'] as List? ?? const [])
        if (p is Map) TeamPerson.fromJson(Map<String, dynamic>.from(p)),
    ],
    canEdit: json['can_edit'] == true,
  );

  final List<TeamDepartment> departments;
  final List<TeamPerson> people;
  final bool canEdit;

  /// The people on a post, by name.
  List<TeamPerson> on(String post) => [
    for (final p in people)
      if (p.active && p.posts.contains(post)) p,
  ];

  /// Nobody on any post yet — hired, not yet placed.
  List<TeamPerson> get unplaced => [
    for (final p in people)
      if (p.active && p.posts.isEmpty) p,
  ];

  /// Left the company, or the login closed: kept, and can come back.
  List<TeamPerson> get left => [
    for (final p in people)
      if (!p.active) p,
  ];
}
