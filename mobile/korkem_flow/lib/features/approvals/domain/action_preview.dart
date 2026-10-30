import 'package:flutter/foundation.dart';

/// A single discrete field in an action preview,
/// e.g. "Клиент" -> "Ерлан Сериков".
@immutable
class ActionPreviewField {
  const ActionPreviewField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionPreviewField &&
          other.label == label &&
          other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'ActionPreviewField($label: $value)';
}

/// Human-readable details of what an action will perform if approved.
@immutable
class ActionPreview {
  const ActionPreview({
    this.title,
    this.fields = const [],
  });

  /// Short headline of the proposed change, e.g. "Будет создан счёт".
  final String? title;

  /// Discrete key-value fields describing the action details.
  final List<ActionPreviewField> fields;

  bool get isEmpty =>
      (title == null || title!.trim().isEmpty) && fields.isEmpty;

  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionPreview &&
          other.title == title &&
          listEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(fields));

  @override
  String toString() => 'ActionPreview(title: $title, fields: $fields)';
}
