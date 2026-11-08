import 'package:flutter/foundation.dart';

/// The order form's lists, each kept by the owner himself — OnayBaza's blue
/// button beside every drop-down (`services/mdf_dictionaries.py`).
enum MdfDictKind {
  /// МДФ, ЛМДФ, ХДФ — the board; its thickness is its own list (09.11.2026).
  material,
  thickness,
  finish,
  decor,
  patina,
  milling,

  /// The facade's edge: R0 … R5, полукруг, ступенька, фаска.
  edge,

  /// The bank of a transfer or a card payment: Kaspi, Halyk, Forte …
  bank,

  /// A paint group's colours: RAL 9010, NCS S 3040-Y60R … (09.11.2026).
  paint;

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

/// «16 мм ЛМДФ» → 16: the thickness a material's name starts with; the
/// order keeps it as a number.
int? thicknessOf(String? value) {
  final m = RegExp(r'^\D*(\d+)').firstMatch(value ?? '');
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// What a drop-down offers: the list, and the value already chosen even if
/// it has since left the list (an order keeps what it was written with).
List<String> mdfChoices(List<String> values, String? current) => [
  ...values,
  if (current != null && current.isNotEmpty && !values.contains(current))
    current,
];

/// Every position's edge unless the manager picks another (owner,
/// 08.11.2026); R0 is a sharp corner. Both need no list and cannot be
/// renamed or deleted.
const mdfDefaultEdge = 'R3';
const List<String> mdfStandardEdges = ['R0', mdfDefaultEdge];

/// The radii to choose from: the two standard ones, then the list's.
List<String> mdfEdges(List<String> listed) => [
  ...mdfStandardEdges,
  for (final e in listed)
    if (!mdfStandardEdges.contains(e)) e,
];

/// How a thickness shows: the list's own words for it («16 мм»), else the
/// millimetres; null for none.
String? mdfThicknessLabel(List<String> listed, int? mm) => mm == null
    ? null
    : listed.firstWhere((v) => thicknessOf(v) == mm, orElse: () => '$mm мм');
