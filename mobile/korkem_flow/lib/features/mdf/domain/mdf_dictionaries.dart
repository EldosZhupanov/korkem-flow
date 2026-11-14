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

  /// The colour systems paints are filed under — RAL Classic, RAL Effect,
  /// NCS, «По образцу» (owner, 15.11.2026).
  paintSystem,

  /// A PVC film's maker — KIRA, JS Group, МС-Груп … (10.11.2026).
  maker,

  /// A PVC film's type — матовая, софт, древесная, глянец … (10.11.2026).
  filmType,

  /// A roll's thickness and width — 0,3 · 0,35; 1400 · 1200 (11.11.2026).
  filmThickness,
  filmWidth,

  /// How a film roll came — такси, Газель, КАМАЗ … — and from which city
  /// (owner, 11.11.2026).
  transport,
  city;

  String get wire => switch (this) {
    MdfDictKind.filmType => 'film_type',
    MdfDictKind.filmThickness => 'film_thickness',
    MdfDictKind.filmWidth => 'film_width',
    MdfDictKind.paintSystem => 'paint_system',
    _ => name,
  };
}

@immutable
class MdfDictEntry {
  const MdfDictEntry({required this.id, required this.value, this.group});

  final String id;
  final String value;

  /// A milling variant's group — «Рифлёный» for «Рифлёный 16-14»
  /// (owner, 14.11.2026); a paint's colour system — «RAL Classic» for
  /// «RAL 9010» (15.11.2026); null for a group, an unfiled paint, and for
  /// every other list.
  final String? group;
}

/// A milling group and its variants, in the list's order.
typedef MdfMillingGroup = ({
  MdfDictEntry? head,
  String name,
  List<MdfDictEntry> variants,
});

/// A colour system and its colours (owner, 15.11.2026). [head] is the
/// system's own entry; null for one that has left the list, and for the
/// colours filed under none, whose [name] is empty.
typedef MdfPaintGroup = ({
  MdfDictEntry? head,
  String name,
  List<MdfDictEntry> colours,
});

@immutable
class MdfDictionaries {
  const MdfDictionaries(this._lists);

  factory MdfDictionaries.fromJson(Map<String, dynamic> json) =>
      MdfDictionaries({
        for (final kind in MdfDictKind.values)
          kind: [
            for (final e in json[kind.wire] as List? ?? const [])
              if (e is Map)
                MdfDictEntry(
                  id: '${e['id']}',
                  value: '${e['value']}',
                  group: e['group'] == null ? null : '${e['group']}',
                ),
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

  /// The milling list as groups (owner, 14.11.2026): each group, then its
  /// variants; a variant whose group has left the list keeps a group of
  /// its own name, without a head.
  List<MdfMillingGroup> millingGroups() {
    final all = entries(MdfDictKind.milling);
    final heads = [
      for (final e in all)
        if (e.group == null) e,
    ];
    final names = {for (final h in heads) h.value};
    final orphans = <String>{
      for (final e in all)
        if (e.group != null && !names.contains(e.group)) e.group!,
    };
    List<MdfDictEntry> under(String name) => [
      for (final e in all)
        if (e.group == name) e,
    ];
    return [
      for (final h in heads) (head: h, name: h.value, variants: under(h.value)),
      for (final o in orphans) (head: null, name: o, variants: under(o)),
    ]..sort((a, b) => mdfNaturalCompare(a.name, b.name));
  }

  /// The paints by colour system, in the systems' order; the colours filed
  /// under none come last.
  List<MdfPaintGroup> paintGroups() {
    final systems = entries(MdfDictKind.paintSystem);
    final paints = entries(MdfDictKind.paint);
    final names = {for (final s in systems) s.value};
    final orphans = <String>{
      for (final p in paints)
        if (p.group != null && !names.contains(p.group)) p.group!,
    };
    List<MdfDictEntry> under(String? name) => [
      for (final p in paints)
        if (p.group == name) p,
    ];
    final loose = under(null);
    return [
      for (final s in systems) (head: s, name: s.value, colours: under(s.value)),
      for (final o in orphans) (head: null, name: o, colours: under(o)),
      if (loose.isNotEmpty) (head: null, name: '', colours: loose),
    ];
  }
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

/// A new order's board when nothing says otherwise (owner, 14.11.2026):
/// our 16 mm LMDF. Each position may still pick another, or the customer's.
const mdfDefaultThicknessMm = 16;
const mdfDefaultMaterial = 'ЛМДФ';

/// [mdfDefaultMaterial] as the factory's list spells it, if it is there.
String? mdfDefaultMaterialIn(List<String> materials) {
  for (final m in materials) {
    if (m.trim().toLowerCase() == mdfDefaultMaterial.toLowerCase()) return m;
  }
  return null;
}

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
