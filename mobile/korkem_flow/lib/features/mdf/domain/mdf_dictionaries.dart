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
  paint,

  /// A PVC film's maker — KIRA, JS Group, МС-Груп … (10.11.2026).
  maker,

  /// A PVC film's type — матовая, софт, древесная, глянец … (10.11.2026).
  filmType;

  String get wire => switch (this) {
    MdfDictKind.filmType => 'film_type',
    _ => name,
  };
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
          ]..sort((a, b) => mdfNaturalCompare(a.value, b.value)),
      });

  static const empty = MdfDictionaries({});

  final Map<MdfDictKind, List<MdfDictEntry>> _lists;

  /// In order (owner, 09.11.2026): numbers by size — 8 мм before 10 мм,
  /// R0 before R3, RAL 9010 before RAL 9016 — words by alphabet.
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

/// «R0» before «R3» before «R10», «8 мм» before «10 мм», «RAL 9010» before
/// «RAL 10000»; words by alphabet, Latin before Cyrillic. Where two values
/// share what comes before their first number, the number decides.
int mdfNaturalCompare(String a, String b) {
  final digits = RegExp(r'\d+');
  final ma = digits.firstMatch(a);
  final mb = digits.firstMatch(b);
  if (ma != null && mb != null) {
    final pa = a.substring(0, ma.start).toLowerCase();
    final pb = b.substring(0, mb.start).toLowerCase();
    if (pa == pb) {
      final byNumber = int.parse(ma[0]!).compareTo(int.parse(mb[0]!));
      if (byNumber != 0) return byNumber;
    }
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}
