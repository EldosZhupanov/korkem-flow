import 'package:meta/meta.dart';

/// «Обмен с 1С»: whether the company exchanges with 1C, and what it hands over.
@immutable
class OneCSettings {
  const OneCSettings({
    required this.enabled,
    required this.canEdit,
    required this.tables,
  });

  factory OneCSettings.fromJson(Map<String, dynamic> json) => OneCSettings(
    enabled: json['enabled'] != false,
    canEdit: json['can_edit'] == true,
    tables: [
      for (final row in json['tables'] as List? ?? const [])
        if (row is Map)
          (table: '${row['table'] ?? ''}', title: '${row['title'] ?? ''}'),
    ],
  );

  final bool enabled;
  final bool canEdit;

  /// Server keys (`sales`, `payments`, …) and the titles 1C users know.
  final List<({String table, String title})> tables;
}

/// One table for a period, as text 1C loads.
@immutable
class OneCExport {
  const OneCExport({
    required this.table,
    required this.rows,
    required this.filename,
    required this.csv,
  });

  factory OneCExport.fromJson(Map<String, dynamic> json) => OneCExport(
    table: '${json['table'] ?? ''}',
    rows: (json['rows'] as num?)?.toInt() ?? 0,
    filename: '${json['filename'] ?? ''}',
    csv: '${json['csv'] ?? ''}',
  );

  final String table;
  final int rows;
  final String filename;
  final String csv;
}
