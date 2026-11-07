import 'package:flutter/foundation.dart';

/// The order form's lists, each kept by the owner himself — OnayBaza's blue
/// button beside every drop-down (`services/mdf_dictionaries.py`).
enum MdfDictKind {
  thickness,
  finish,
  decor,
  patina,
  milling,
  edge;

  String get wire => name;
}

@immutable
class MdfDictEntry {
  const MdfDictEntry({required this.id, required this.value});

  final String id;
  final String value;
}

@immutable
class MdfDictionaries {
  const MdfDictionaries(this._lists);

  factory MdfDictionaries.fromJson(Map<String, dynamic> json) =>
      MdfDictionaries({
        for (final kind in MdfDictKind.values)
          kind: [
            for (final e in json[kind.wire] as List? ?? const [])
              if (e is Map)
                MdfDictEntry(id: '${e['id']}', value: '${e['value']}'),
          ],
      });

  static const empty = MdfDictionaries({});

  final Map<MdfDictKind, List<MdfDictEntry>> _lists;

  /// In the order they were added.
  List<MdfDictEntry> entries(MdfDictKind kind) => _lists[kind] ?? const [];

  List<String> values(MdfDictKind kind) => [
    for (final e in entries(kind)) e.value,
  ];
}

/// «16 мм» → 16: the order keeps the thickness as a number.
int? thicknessOf(String? value) {
  final digits = (value ?? '').replaceAll(RegExp('[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// What a drop-down offers: the list, and the value already chosen even if
/// it has since left the list (an order keeps what it was written with).
List<String> mdfChoices(List<String> values, String? current) => [
  ...values,
  if (current != null && current.isNotEmpty && !values.contains(current))
    current,
];
