import 'package:meta/meta.dart';

/// One value in a list the managers keep (a thickness, a maker, a colour).
@immutable
class MaterialOption {
  const MaterialOption({
    required this.option,
    required this.value,
    this.enabled = true,
  });

  factory MaterialOption.fromJson(Map<String, dynamic> json) => MaterialOption(
    option: '${json['option'] ?? ''}',
    value: '${json['value'] ?? ''}',
    enabled: json['enabled'] != false,
  );

  final String option;
  final String value;
  final bool enabled;
}

/// A supplier (ERPNext Supplier).
@immutable
class MaterialSupplier {
  const MaterialSupplier({
    required this.supplier,
    required this.name,
    this.enabled = true,
  });

  factory MaterialSupplier.fromJson(Map<String, dynamic> json) =>
      MaterialSupplier(
        supplier: '${json['supplier'] ?? ''}',
        name: '${json['name'] ?? json['supplier'] ?? ''}',
        enabled: json['enabled'] != false,
      );

  final String supplier;
  final String name;
  final bool enabled;
}

/// All lists, suppliers and units, and whether this person may edit them.
@immutable
class MaterialLists {
  const MaterialLists({
    required this.lists,
    required this.suppliers,
    required this.units,
    required this.canEdit,
  });

  factory MaterialLists.fromJson(Map<String, dynamic> json) {
    final raw = json['lists'] is Map
        ? Map<String, dynamic>.from(json['lists'] as Map)
        : const <String, dynamic>{};
    return MaterialLists(
      lists: {
        for (final entry in raw.entries)
          entry.key: [
            for (final row in entry.value as List? ?? const [])
              if (row is Map)
                MaterialOption.fromJson(Map<String, dynamic>.from(row)),
          ],
      },
      suppliers: [
        for (final row in json['suppliers'] as List? ?? const [])
          if (row is Map)
            MaterialSupplier.fromJson(Map<String, dynamic>.from(row)),
      ],
      units: [
        for (final u in json['units'] as List? ?? const [])
          if (u is String) u,
      ],
      canEdit: json['can_edit'] == true,
    );
  }

  static const mdfThickness = 'Толщина МДФ';
  static const manufacturer = 'Производитель';
  static const filmColor = 'Цвет плёнки';
  static const filmWidth = 'Ширина плёнки';
  static const filmThickness = 'Толщина плёнки';

  /// R3, 90° … — read by the facade positions of orders, not by materials.
  static const edgeProfile = 'Профиль кромки';
  static const List<String> all = [
    mdfThickness,
    manufacturer,
    filmColor,
    filmWidth,
    filmThickness,
    edgeProfile,
  ];

  final Map<String, List<MaterialOption>> lists;
  final List<MaterialSupplier> suppliers;
  final List<String> units;
  final bool canEdit;

  /// Values in use — what a new material may be described with.
  List<String> enabled(String list) => [
    for (final o in lists[list] ?? const <MaterialOption>[])
      if (o.enabled) o.value,
  ];
}

/// A stocked material with what is on hand.
@immutable
class StockMaterial {
  const StockMaterial({
    required this.item,
    required this.title,
    required this.kind,
    required this.unit,
    required this.onHand,
    this.reserved = 0,
    double? free,
    this.averagePrice,
    this.enabled = true,
    this.textured = false,
  }) : free = free ?? onHand - reserved;

  factory StockMaterial.fromJson(Map<String, dynamic> json) {
    final onHand = (json['on_hand'] as num?)?.toDouble() ?? 0;
    return StockMaterial(
      item: '${json['item'] ?? ''}',
      title: '${json['title'] ?? ''}',
      kind: '${json['kind'] ?? ''}',
      unit: '${json['unit'] ?? ''}',
      onHand: onHand,
      reserved: (json['reserved'] as num?)?.toDouble() ?? 0,
      free: (json['free'] as num?)?.toDouble(),
      averagePrice: (json['average_price'] as num?)?.toDouble(),
      enabled: json['enabled'] != false,
      textured: json['textured'] == true,
    );
  }

  static const mdf = 'МДФ';
  static const film = 'Плёнка ПВХ';
  static const other = 'Прочее';
  static const List<String> kinds = [mdf, film, other];

  final String item;
  final String title;
  final String kind;
  final String unit;
  final double onHand;

  /// Promised to orders and not yet written off. On hand is ERPNext's figure;
  /// a reservation only narrows what is [free].
  final double reserved;
  final double free;

  /// `null` when prices are hidden from this person.
  final double? averagePrice;
  final bool enabled;

  /// A film whose pattern has a direction: never turned on the press.
  final bool textured;
}

/// One material a facade order needs, counted on the server from its m².
@immutable
class FacadeMaterialNeed {
  const FacadeMaterialNeed({
    required this.kind,
    required this.key,
    required this.areaM2,
    this.item,
    this.title,
    this.unit,
    this.needed,
    this.held = 0,
    this.issued = 0,
    this.free = 0,
    this.short,
    this.note,
  });

  factory FacadeMaterialNeed.fromJson(Map<String, dynamic> json) =>
      FacadeMaterialNeed(
        kind: '${json['kind'] ?? ''}',
        key: '${json['key'] ?? ''}',
        areaM2: (json['area_m2'] as num?)?.toDouble() ?? 0,
        item: json['item'] as String?,
        title: json['title'] as String?,
        unit: json['unit'] as String?,
        needed: (json['needed'] as num?)?.toDouble(),
        held: (json['held'] as num?)?.toDouble() ?? 0,
        issued: (json['issued'] as num?)?.toDouble() ?? 0,
        free: (json['free'] as num?)?.toDouble() ?? 0,
        short: (json['short'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );

  final String kind;

  /// The thickness of an MDF or the decor of a film.
  final String key;
  final double areaM2;
  final String? item;
  final String? title;
  final String? unit;

  /// `null` when the server could not count it — [note] says why.
  final double? needed;
  final double held;
  final double issued;
  final double free;
  final double? short;
  final String? note;

  bool get isShort => note != null || (short ?? 0) > 0;
}

/// What a facade order needs from the warehouse, as a whole.
@immutable
class FacadeMaterials {
  const FacadeMaterials({
    required this.materials,
    required this.unresolved,
    required this.fullyHeld,
  });

  factory FacadeMaterials.fromJson(Map<String, dynamic> json) =>
      FacadeMaterials(
        materials: [
          for (final row in json['materials'] as List? ?? const [])
            if (row is Map)
              FacadeMaterialNeed.fromJson(Map<String, dynamic>.from(row)),
        ],
        unresolved: [
          for (final note in json['unresolved'] as List? ?? const [])
            if (note is String) note,
        ],
        fullyHeld: json['fully_held'] == true,
      );

  final List<FacadeMaterialNeed> materials;

  /// Lines the server could not place: no thickness, no decor.
  final List<String> unresolved;
  final bool fullyHeld;
}
