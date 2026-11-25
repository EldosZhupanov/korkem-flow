import 'package:flutter/foundation.dart';

/// A stage of an order given to a person and not yet done.
@immutable
class TeamOpenWork {
  const TeamOpenWork({
    required this.order,
    required this.stage,
    this.number,
    this.customer,
  });

  factory TeamOpenWork.fromJson(Map<String, dynamic> json) => TeamOpenWork(
    order: '${json['order']}',
    stage: '${json['stage']}',
    number: json['number'] is num ? (json['number'] as num).toInt() : null,
    customer: json['customer'] == null ? null : '${json['customer']}',
  );

  final String order;
  final String stage;
  final int? number;
  final String? customer;
}

/// What to know before «Уволен»: his open stages and, for those who see
/// pay, what is not settled.
@immutable
class TeamDismissal {
  const TeamDismissal({this.open = const [], this.left, this.pending});

  factory TeamDismissal.fromJson(Map<String, dynamic> json) {
    final money = json['money'] is Map
        ? Map<String, dynamic>.from(json['money'] as Map)
        : null;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    return TeamDismissal(
      open: [
        for (final w in json['open'] as List? ?? const [])
          if (w is Map) TeamOpenWork.fromJson(Map<String, dynamic>.from(w)),
      ],
      left: d(money?['left']),
      pending: d(money?['pending']),
    );
  }

  final List<TeamOpenWork> open;

  /// To pay him (above zero) or his advances over his earnings (below);
  /// null — not for this reader, or no login.
  final double? left;
  final double? pending;

  bool get settled =>
      open.isEmpty && (left ?? 0) == 0 && (pending ?? 0) == 0;
}

/// Someone already on the list with this name or phone.
@immutable
class TeamDuplicate {
  const TeamDuplicate({
    required this.employee,
    required this.name,
    this.phone,
    this.active = true,
    this.posts = const [],
    this.byPhone = false,
  });

  factory TeamDuplicate.fromJson(Map<String, dynamic> json) => TeamDuplicate(
    employee: '${json['employee']}',
    name: '${json['name'] ?? json['employee']}',
    phone: json['phone'] == null ? null : '${json['phone']}',
    active: json['active'] != false,
    posts: [for (final p in json['posts'] as List? ?? const []) '$p'],
    byPhone: json['by'] == 'phone',
  );

  final String employee;
  final String name;
  final String? phone;
  final bool active;
  final List<String> posts;
  final bool byPhone;
}

/// A line of a person's history: a post given or taken, hired, left.
enum TeamEventKind { added, postOn, postOff, left, back }

@immutable
class TeamEvent {
  const TeamEvent({
    required this.on,
    required this.kind,
    this.post,
    this.by,
  });

  factory TeamEvent.fromJson(Map<String, dynamic> json) => TeamEvent(
    on: '${json['on']}',
    kind: switch (json['kind']) {
      'added' => TeamEventKind.added,
      'post_on' => TeamEventKind.postOn,
      'post_off' => TeamEventKind.postOff,
      'left' => TeamEventKind.left,
      _ => TeamEventKind.back,
    },
    post: json['post'] == null ? null : '${json['post']}',
    by: json['by'] == null ? null : '${json['by']}',
  );

  /// `yyyy-MM-dd`.
  final String on;
  final TeamEventKind kind;
  final String? post;
  final String? by;
}
