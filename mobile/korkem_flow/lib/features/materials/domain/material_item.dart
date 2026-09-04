import 'package:flutter/foundation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Semantic classification of a material: board (sheet material)
/// or edge (edging tape).
enum MaterialKind {
  board,
  edge;

  static MaterialKind fromString(String? value) {
    if (value == 'edge') return MaterialKind.edge;
    return MaterialKind.board;
  }
}

/// A material record from the manufacturing catalogue.
///
/// Only [id], [name], and [kind] are guaranteed by the server.
/// All physical dimensions, decor codes, and manufacturer references
/// remain null if omitted by the server — never substituted with
/// plausible defaults.
@immutable
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.name,
    required this.kind,
    this.manufacturer,
    this.decorCode,
    this.thicknessMm,
    this.sheetWidthMm,
    this.sheetHeightMm,
    this.edgeWidthMm,
    this.fitsThicknessMm,
    this.colorFamily,
    this.active = true,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['name'] ?? '').toString().trim();
    final name = (json['name'] ?? json['material_name'] ?? id)
        .toString()
        .trim();
    final kind = MaterialKind.fromString(json['kind']?.toString());

    final rawManufacturer = json['manufacturer']?.toString().trim();
    final manufacturer = (rawManufacturer == null || rawManufacturer.isEmpty)
        ? null
        : rawManufacturer;

    final rawDecorCode = json['decor_code']?.toString().trim();
    final decorCode = (rawDecorCode == null || rawDecorCode.isEmpty)
        ? null
        : rawDecorCode;

    final rawThickness = json['thickness_mm'];
    final thicknessMm = switch (rawThickness) {
      num() => rawThickness.toDouble(),
      String() => double.tryParse(rawThickness),
      _ => null,
    };

    final rawWidth = json['sheet_width_mm'];
    final sheetWidthMm = switch (rawWidth) {
      num() => rawWidth.round(),
      String() => int.tryParse(rawWidth),
      _ => null,
    };

    final rawHeight = json['sheet_height_mm'];
    final sheetHeightMm = switch (rawHeight) {
      num() => rawHeight.round(),
      String() => int.tryParse(rawHeight),
      _ => null,
    };

    final rawEdgeWidth = json['edge_width_mm'];
    final edgeWidthMm = switch (rawEdgeWidth) {
      num() => rawEdgeWidth.toDouble(),
      String() => double.tryParse(rawEdgeWidth),
      _ => null,
    };

    final rawFits = json['fits_thickness_mm'];
    final fitsThicknessMm = switch (rawFits) {
      num() => rawFits.toDouble(),
      String() => double.tryParse(rawFits),
      _ => null,
    };

    final rawColor = json['color_family']?.toString().trim();
    final colorFamily = (rawColor == null || rawColor.isEmpty)
        ? null
        : rawColor;

    final rawActive = json['active'];
    final active = switch (rawActive) {
      bool() => rawActive,
      num() => rawActive != 0,
      String() => rawActive.toLowerCase() == 'true' || rawActive == '1',
      _ => true,
    };

    return MaterialItem(
      id: id,
      name: name,
      kind: kind,
      manufacturer: manufacturer,
      decorCode: decorCode,
      thicknessMm: thicknessMm,
      sheetWidthMm: sheetWidthMm,
      sheetHeightMm: sheetHeightMm,
      edgeWidthMm: edgeWidthMm,
      fitsThicknessMm: fitsThicknessMm,
      colorFamily: colorFamily,
      active: active,
    );
  }

  final String id;
  final String name;
  final MaterialKind kind;
  final String? manufacturer;
  final String? decorCode;
  final double? thicknessMm;
  final int? sheetWidthMm;
  final int? sheetHeightMm;
  final double? edgeWidthMm;
  final double? fitsThicknessMm;
  final String? colorFamily;
  final bool active;

  /// Whether this material is a sheet board.
  bool get isBoard => kind == MaterialKind.board;

  /// Whether this material is edge banding.
  bool get isEdge => kind == MaterialKind.edge;

  /// Prominent display title for cabinet makers: decor code first, then name.
  /// If decor code is missing, falls back to the name alone.
  String get displayTitle {
    final code = decorCode;
    if (code != null && code.isNotEmpty) {
      return '$code · $name';
    }
    return name;
  }

  /// Formatted thickness string, e.g. "16 mm" or "0.4 mm".
  /// Returns null if [thicknessMm] is null.
  String? formattedThickness(AppLocalizations l10n) {
    final thickness = thicknessMm;
    if (thickness == null) return null;
    final formatted = thickness == thickness.roundToDouble()
        ? thickness.toInt().toString()
        : thickness.toString();
    return l10n.materialsThicknessLabel(formatted);
  }

  /// Formatted sheet dimensions, e.g. "2800×2070 mm".
  /// Returns null if either width or height is null.
  String? formattedSheetDimensions(AppLocalizations l10n) {
    final width = sheetWidthMm;
    final height = sheetHeightMm;
    if (width == null || height == null) return null;
    return l10n.materialsFormatDimensions(width, height);
  }

  /// Formatted board thickness that this edge fits, e.g. "под 18 мм".
  /// Returns null if [fitsThicknessMm] is null.
  String? formattedFitsThickness(AppLocalizations l10n) {
    final fits = fitsThicknessMm;
    if (fits == null) return null;
    final formatted = fits == fits.roundToDouble()
        ? fits.toInt().toString()
        : fits.toString();
    return l10n.materialsFitsThickness(formatted);
  }

  /// Formatted edge width string, e.g. "ширина 22 мм".
  /// Returns null if [edgeWidthMm] is null.
  String? formattedEdgeWidth(AppLocalizations l10n) {
    final width = edgeWidthMm;
    if (width == null) return null;
    final formatted = width == width.roundToDouble()
        ? width.toInt().toString()
        : width.toString();
    return l10n.materialsEdgeWidth(formatted);
  }

  /// Formats color family into localized string, or null if missing.
  String? localizedColorFamily(AppLocalizations l10n) {
    return switch (colorFamily?.toLowerCase()) {
      'white' => l10n.materialsColorWhite,
      'wood' => l10n.materialsColorWood,
      'grey' || 'gray' => l10n.materialsColorGrey,
      'black' => l10n.materialsColorBlack,
      _ => colorFamily,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    if (manufacturer != null) 'manufacturer': manufacturer,
    if (decorCode != null) 'decor_code': decorCode,
    if (thicknessMm != null) 'thickness_mm': thicknessMm,
    if (sheetWidthMm != null) 'sheet_width_mm': sheetWidthMm,
    if (sheetHeightMm != null) 'sheet_height_mm': sheetHeightMm,
    if (edgeWidthMm != null) 'edge_width_mm': edgeWidthMm,
    if (fitsThicknessMm != null) 'fits_thickness_mm': fitsThicknessMm,
    if (colorFamily != null) 'color_family': colorFamily,
    'active': active,
  };
}
