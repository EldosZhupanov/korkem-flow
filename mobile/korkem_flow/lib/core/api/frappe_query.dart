import 'dart:convert';

import 'package:meta/meta.dart';

/// A Frappe list filter: `[fieldname, operator, value]`.
///
/// Frappe expects filters as a JSON array of triples on the query string. This
/// type exists so that shape is produced in exactly one place — hand-built
/// query strings are how field-name typos reach production.
@immutable
class FrappeFilter {
  const FrappeFilter(this.field, this.operator, this.value);

  const FrappeFilter.equals(String field, Object? value)
    : this(field, '=', value);

  const FrappeFilter.notEquals(String field, Object? value)
    : this(field, '!=', value);

  const FrappeFilter.like(String field, String value)
    : this(field, 'like', value);

  const FrappeFilter.isIn(String field, List<Object?> values)
    : this(field, 'in', values);

  final String field;
  final String operator;
  final Object? value;

  List<Object?> toJson() => [field, operator, value];

  @override
  bool operator ==(Object other) =>
      other is FrappeFilter &&
      other.field == field &&
      other.operator == operator &&
      other.value.toString() == value.toString();

  @override
  int get hashCode => Object.hash(field, operator, value.toString());
}

/// Typed builder for a Frappe `/api/resource` list query.
///
/// Verified against the running backend — see docs/backend_api_audit.md §2.
@immutable
class FrappeQuery {
  const FrappeQuery({
    this.fields = const ['name'],
    this.filters = const [],
    this.orderBy,
    this.limitStart = 0,
    this.limitPageLength = 20,
  });

  final List<String> fields;
  final List<FrappeFilter> filters;

  /// e.g. `'modified desc'`. Frappe expects `"<field> <asc|desc>"`.
  final String? orderBy;
  final int limitStart;
  final int limitPageLength;

  FrappeQuery nextPage() => copyWith(limitStart: limitStart + limitPageLength);

  FrappeQuery copyWith({
    List<String>? fields,
    List<FrappeFilter>? filters,
    String? orderBy,
    int? limitStart,
    int? limitPageLength,
  }) {
    return FrappeQuery(
      fields: fields ?? this.fields,
      filters: filters ?? this.filters,
      orderBy: orderBy ?? this.orderBy,
      limitStart: limitStart ?? this.limitStart,
      limitPageLength: limitPageLength ?? this.limitPageLength,
    );
  }

  /// Frappe requires `fields` and `filters` as JSON-encoded strings, not as
  /// repeated query parameters.
  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'fields': jsonEncode(fields),
      if (filters.isNotEmpty)
        'filters': jsonEncode(filters.map((f) => f.toJson()).toList()),
      if (orderBy != null) 'order_by': orderBy,
      'limit_start': limitStart,
      'limit_page_length': limitPageLength,
    };
  }

  /// Stable identity for cache keying: two queries with the same signature
  /// address the same result set.
  String get signature => jsonEncode(toQueryParameters());

  @override
  bool operator ==(Object other) =>
      other is FrappeQuery && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}
