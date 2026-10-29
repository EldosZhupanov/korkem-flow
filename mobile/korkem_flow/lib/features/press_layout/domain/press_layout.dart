import 'package:meta/meta.dart';

/// One facade on a press load, in millimetres from the table's corner:
/// [x] along the table, [y] across it.
@immutable
class PlacedPart {
  const PlacedPart({
    required this.pos,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotated = false,
  });

  factory PlacedPart.fromJson(Map<String, dynamic> json) => PlacedPart(
    pos: (json['pos'] as num?)?.toInt() ?? 0,
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    width: (json['width'] as num?)?.toDouble() ?? 0,
    height: (json['height'] as num?)?.toDouble() ?? 0,
    rotated: json['rotated'] == true,
  );

  /// The order line the facade belongs to — its number on the map.
  final int pos;
  final double x;
  final double y;
  final double width;
  final double height;

  /// Turned 90° from the order's orientation; never for a textured film.
  final bool rotated;
}

/// One load of the press: the section of film it takes and what lies on it.
@immutable
class PressLoad {
  const PressLoad({
    required this.filmM,
    required this.lengthMm,
    required this.placed,
  });

  factory PressLoad.fromJson(Map<String, dynamic> json) => PressLoad(
    filmM: (json['film_m'] as num?)?.toDouble() ?? 0,
    lengthMm: (json['length_mm'] as num?)?.toDouble() ?? 0,
    placed: [
      for (final p in json['placed'] as List? ?? const [])
        if (p is Map) PlacedPart.fromJson(Map<String, dynamic>.from(p)),
    ],
  );

  final double filmM;
  final double lengthMm;
  final List<PlacedPart> placed;
}

/// One film decor of an order on the press: its loads and its metres.
@immutable
class FilmLayout {
  const FilmLayout({
    required this.decor,
    required this.title,
    required this.loads,
    required this.layoutM,
    required this.filmM,
    this.textured = false,
    this.corrected = false,
    this.reason,
    this.tooBig = const [],
  });

  factory FilmLayout.fromJson(Map<String, dynamic> json) => FilmLayout(
    decor: '${json['decor'] ?? ''}',
    title: '${json['title'] ?? ''}',
    textured: json['textured'] == true,
    layoutM: (json['layout_m'] as num?)?.toDouble() ?? 0,
    filmM: (json['film_m'] as num?)?.toDouble() ?? 0,
    corrected: json['corrected'] == true,
    reason: json['reason'] as String?,
    loads: [
      for (final l in json['loads'] as List? ?? const [])
        if (l is Map) PressLoad.fromJson(Map<String, dynamic>.from(l)),
    ],
    tooBig: [
      for (final p in json['too_big'] as List? ?? const [])
        if (p is num) p.toInt(),
    ],
  );

  final String decor;

  /// «№ order · customer · decor» — what the press operator reads first.
  final String title;
  final bool textured;

  /// Metres the layout takes, and the metres in use (a manager's correction).
  final double layoutM;
  final double filmM;
  final bool corrected;
  final String? reason;
  final List<PressLoad> loads;

  /// Order lines larger than the press table.
  final List<int> tooBig;
}

/// The press: its working area, the margin, the gap, and its sections.
@immutable
class PressSettings {
  const PressSettings({
    required this.lengthMm,
    required this.widthMm,
    required this.marginMm,
    required this.gapMm,
    required this.sections,
    this.canEdit = false,
  });

  factory PressSettings.fromJson(Map<String, dynamic> json) => PressSettings(
    lengthMm: (json['press_length_mm'] as num?)?.toDouble() ?? 0,
    widthMm: (json['press_width_mm'] as num?)?.toDouble() ?? 0,
    marginMm: (json['press_margin_mm'] as num?)?.toDouble() ?? 0,
    gapMm: (json['press_gap_mm'] as num?)?.toDouble() ?? 0,
    sections: [
      for (final s in json['press_sections'] as List? ?? const [])
        if (s is Map)
          (
            filmM: (s['film_m'] as num?)?.toDouble() ?? 0,
            lengthMm: (s['length_mm'] as num?)?.toDouble() ?? 0,
          ),
    ],
    canEdit: json['can_edit'] == true,
  );

  final double lengthMm;
  final double widthMm;
  final double marginMm;
  final double gapMm;

  /// Film ordered for a section, and the working length it gives.
  final List<({double filmM, double lengthMm})> sections;
  final bool canEdit;
}

/// An order's films on the press.
@immutable
class OrderPressLayout {
  const OrderPressLayout({
    required this.salesOrder,
    required this.press,
    required this.films,
    this.canCorrect = false,
  });

  factory OrderPressLayout.fromJson(Map<String, dynamic> json) =>
      OrderPressLayout(
        salesOrder: '${json['sales_order'] ?? ''}',
        press: PressSettings.fromJson(
          json['press'] is Map
              ? Map<String, dynamic>.from(json['press'] as Map)
              : const {},
        ),
        films: [
          for (final f in json['films'] as List? ?? const [])
            if (f is Map) FilmLayout.fromJson(Map<String, dynamic>.from(f)),
        ],
        canCorrect: json['can_correct'] == true,
      );

  final String salesOrder;
  final PressSettings press;
  final List<FilmLayout> films;
  final bool canCorrect;
}
