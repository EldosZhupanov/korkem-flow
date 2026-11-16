import 'package:flutter/foundation.dart';

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

/// A person at the company — with or without a login ([user]).
@immutable
class TeamPerson {
  const TeamPerson({
    required this.employee,
    required this.name,
    this.phone,
    this.user,
    this.active = true,
    this.posts = const [],
  });

  factory TeamPerson.fromJson(Map<String, dynamic> json) => TeamPerson(
    employee: '${json['employee']}',
    name: '${json['name'] ?? json['employee']}',
    phone: json['phone'] == null || '${json['phone']}'.isEmpty
        ? null
        : '${json['phone']}',
    user: json['user'] == null || '${json['user']}'.isEmpty
        ? null
        : '${json['user']}',
    active: json['active'] != false,
    posts: [for (final p in json['posts'] as List? ?? const []) '$p'],
  );

  final String employee;
  final String name;
  final String? phone;
  final String? user;
  final bool active;
  final List<String> posts;
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
      if (p.posts.contains(post)) p,
  ];

  /// Nobody on any post yet — hired, not yet placed.
  List<TeamPerson> get unplaced => [
    for (final p in people)
      if (p.posts.isEmpty) p,
  ];
}
