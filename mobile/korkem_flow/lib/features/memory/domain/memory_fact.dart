import 'package:flutter/foundation.dart';

/// Scope of a memory fact.
enum MemoryScope {
  company('company'),
  user('user');

  const MemoryScope(this.wireValue);

  final String wireValue;

  static MemoryScope fromWire(String? value) {
    if (value == null) return MemoryScope.user;
    for (final scope in MemoryScope.values) {
      if (scope.wireValue == value.toLowerCase()) return scope;
    }
    return MemoryScope.user;
  }
}

/// A piece of long-term knowledge KORKEM remembers about the company or
/// the worker.
@immutable
class MemoryFact {
  const MemoryFact({
    required this.id,
    required this.text,
    required this.scope,
    required this.sourceLabel,
    this.isConfirmed = false,
    this.confirmedAt,
    this.createdAt,
  });

  factory MemoryFact.fromJson(Map<String, dynamic> json) {
    final rawScope = json['scope'] as String?;
    final source = '${json['source_label'] ?? json['source'] ?? ''}'.trim();

    return MemoryFact(
      id: '${json['name'] ?? json['id'] ?? ''}',
      text: '${json['text'] ?? json['fact'] ?? ''}'.trim(),
      scope: MemoryScope.fromWire(rawScope),
      sourceLabel: source.isNotEmpty ? source : '—',
      isConfirmed: json['confirmed'] == true || json['is_confirmed'] == true,
      confirmedAt: DateTime.tryParse('${json['confirmed_at']}'),
      createdAt: DateTime.tryParse('${json['created_at']}'),
    );
  }

  final String id;

  /// The fact statement itself.
  final String text;

  /// Whether this applies to the whole company or to this specific user.
  final MemoryScope scope;

  /// Human-readable provenance (e.g. "из разговора 2 сентября",
  /// "указано вами").
  final String sourceLabel;

  /// Confirmed facts are prioritized and kept longer than system-inferred ones.
  final bool isConfirmed;

  final DateTime? confirmedAt;
  final DateTime? createdAt;

  MemoryFact copyWith({
    String? id,
    String? text,
    MemoryScope? scope,
    String? sourceLabel,
    bool? isConfirmed,
    DateTime? confirmedAt,
    DateTime? createdAt,
  }) {
    return MemoryFact(
      id: id ?? this.id,
      text: text ?? this.text,
      scope: scope ?? this.scope,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': id,
    'text': text,
    'scope': scope.wireValue,
    'source_label': sourceLabel,
    'confirmed': isConfirmed,
    if (confirmedAt != null) 'confirmed_at': confirmedAt!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryFact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          scope == other.scope &&
          sourceLabel == other.sourceLabel &&
          isConfirmed == other.isConfirmed;

  @override
  int get hashCode => Object.hash(id, text, scope, sourceLabel, isConfirmed);
}
