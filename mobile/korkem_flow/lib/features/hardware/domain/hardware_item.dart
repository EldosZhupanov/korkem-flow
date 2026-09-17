import 'package:flutter/foundation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Semantic classification of furniture hardware.
enum HardwareType {
  hinge('hinge'),
  runner('runner'),
  handle('handle'),
  leg('leg'),
  shelfSupport('shelf_support'),
  other('other');

  const HardwareType(this.code);

  final String code;

  static HardwareType fromString(String? value) {
    if (value == null) return HardwareType.other;
    return switch (value.toLowerCase().trim()) {
      'hinge' => HardwareType.hinge,
      'runner' => HardwareType.runner,
      'handle' => HardwareType.handle,
      'leg' => HardwareType.leg,
      'shelf_support' || 'shelfsupport' => HardwareType.shelfSupport,
      _ => HardwareType.other,
    };
  }

  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      HardwareType.hinge => l10n.hardwareTypeHinge,
      HardwareType.runner => l10n.hardwareTypeRunner,
      HardwareType.handle => l10n.hardwareTypeHandle,
      HardwareType.leg => l10n.hardwareTypeLeg,
      HardwareType.shelfSupport => l10n.hardwareTypeShelfSupport,
      HardwareType.other => code,
    };
  }

  String localizedKindChip(AppLocalizations l10n) {
    return switch (this) {
      HardwareType.hinge => l10n.hardwareKindHinge,
      HardwareType.runner => l10n.hardwareKindRunner,
      HardwareType.handle => l10n.hardwareKindHandle,
      HardwareType.leg => l10n.hardwareKindLeg,
      HardwareType.shelfSupport => l10n.hardwareKindShelfSupport,
      HardwareType.other => code,
    };
  }
}

/// Installation overlay rule for hinges.
///
/// Overlay is not merely a descriptive attribute: it is an installation rule
/// that dictates how the door sits against the cabinet carcass:
/// - full: door fully covers the carcass edge (individual carcass or end wall)
/// - half: two doors share a single carcass divider edge
/// - inset: door is recessed inside the carcass opening
enum HingeOverlay {
  full('full'),
  half('half'),
  inset('inset');

  const HingeOverlay(this.code);

  final String code;

  static HingeOverlay? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toLowerCase().trim()) {
      'full' => HingeOverlay.full,
      'half' => HingeOverlay.half,
      'inset' => HingeOverlay.inset,
      _ => null,
    };
  }

  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      HingeOverlay.full => l10n.hardwareOverlayFull,
      HingeOverlay.half => l10n.hardwareOverlayHalf,
      HingeOverlay.inset => l10n.hardwareOverlayInset,
    };
  }

  String installationExplanation(AppLocalizations l10n) {
    return switch (this) {
      HingeOverlay.full => l10n.hardwareOverlayFullExplanation,
      HingeOverlay.half => l10n.hardwareOverlayHalfExplanation,
      HingeOverlay.inset => l10n.hardwareOverlayInsetExplanation,
    };
  }
}

/// Cup drilling hole pattern (distance between mounting screw holes
/// on the hinge cup).
enum MountingSystem {
  austrian('austrian'),
  italian('italian'),
  german('german'),
  mini('mini');

  const MountingSystem(this.code);

  final String code;

  static MountingSystem? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toLowerCase().trim()) {
      'austrian' => MountingSystem.austrian,
      'italian' => MountingSystem.italian,
      'german' => MountingSystem.german,
      'mini' => MountingSystem.mini,
      _ => null,
    };
  }

  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      MountingSystem.austrian => l10n.hardwareMountingAustrian,
      MountingSystem.italian => l10n.hardwareMountingItalian,
      MountingSystem.german => l10n.hardwareMountingGerman,
      MountingSystem.mini => l10n.hardwareMountingMini,
    };
  }
}

/// A furniture hardware item from the catalogue.
///
/// Only [id], [name], and [hardwareType] are guaranteed by the server.
/// All physical dimensions, technical parameters, and brand names remain
/// null if omitted by the server — NEVER substituted with plausible defaults.
@immutable
class HardwareItem {
  const HardwareItem({
    required this.id,
    required this.name,
    required this.hardwareType,
    this.brand,
    this.model,
    this.overlay,
    this.cupDiameterMm,
    this.cupDepthMm,
    this.mountingSystem,
    this.openingAngleDeg,
    this.softClose,
    this.lengthMm,
    this.loadKg,
    this.holeSpacingMm,
    this.colour,
    this.active = true,
  });

  factory HardwareItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['name'] ?? '').toString().trim();
    final name = (json['name'] ?? json['hardware_name'] ?? id)
        .toString()
        .trim();
    final hardwareType = HardwareType.fromString(
      json['hardware_type']?.toString(),
    );

    final rawBrand = json['brand']?.toString().trim();
    final brand = (rawBrand == null || rawBrand.isEmpty) ? null : rawBrand;

    final rawModel = json['model']?.toString().trim();
    final model = (rawModel == null || rawModel.isEmpty) ? null : rawModel;

    final overlay = HingeOverlay.fromString(json['overlay']?.toString());

    final rawCupDia = json['cup_diameter_mm'];
    final cupDiameterMm = switch (rawCupDia) {
      num() => rawCupDia.toDouble(),
      String() => double.tryParse(rawCupDia),
      _ => null,
    };

    final rawCupDepth = json['cup_depth_mm'];
    final cupDepthMm = switch (rawCupDepth) {
      num() => rawCupDepth.toDouble(),
      String() => double.tryParse(rawCupDepth),
      _ => null,
    };

    final mountingSystem = MountingSystem.fromString(
      json['mounting_system']?.toString(),
    );

    final rawAngle = json['opening_angle_deg'];
    final openingAngleDeg = switch (rawAngle) {
      num() => rawAngle.toDouble(),
      String() => double.tryParse(rawAngle),
      _ => null,
    };

    final rawSoftClose = json['soft_close'];
    final softClose = switch (rawSoftClose) {
      bool() => rawSoftClose,
      num() => rawSoftClose != 0,
      String() => switch (rawSoftClose.toLowerCase().trim()) {
        'true' || '1' || 'yes' => true,
        'false' || '0' || 'no' => false,
        _ => null,
      },
      _ => null,
    };

    final rawLength = json['length_mm'];
    final lengthMm = switch (rawLength) {
      num() => rawLength.toDouble(),
      String() => double.tryParse(rawLength),
      _ => null,
    };

    final rawLoad = json['load_kg'];
    final loadKg = switch (rawLoad) {
      num() => rawLoad.toDouble(),
      String() => double.tryParse(rawLoad),
      _ => null,
    };

    final rawHoleSpacing = json['hole_spacing_mm'];
    final holeSpacingMm = switch (rawHoleSpacing) {
      num() => rawHoleSpacing.toDouble(),
      String() => double.tryParse(rawHoleSpacing),
      _ => null,
    };

    final rawColour = json['colour']?.toString().trim();
    final colour = (rawColour == null || rawColour.isEmpty) ? null : rawColour;

    final rawActive = json['active'];
    final active = switch (rawActive) {
      bool() => rawActive,
      num() => rawActive != 0,
      String() => rawActive.toLowerCase() == 'true' || rawActive == '1',
      _ => true,
    };

    return HardwareItem(
      id: id,
      name: name,
      hardwareType: hardwareType,
      brand: brand,
      model: model,
      overlay: overlay,
      cupDiameterMm: cupDiameterMm,
      cupDepthMm: cupDepthMm,
      mountingSystem: mountingSystem,
      openingAngleDeg: openingAngleDeg,
      softClose: softClose,
      lengthMm: lengthMm,
      loadKg: loadKg,
      holeSpacingMm: holeSpacingMm,
      colour: colour,
      active: active,
    );
  }

  final String id;
  final String name;
  final HardwareType hardwareType;
  final String? brand;
  final String? model;
  final HingeOverlay? overlay;
  final double? cupDiameterMm;
  final double? cupDepthMm;
  final MountingSystem? mountingSystem;
  final double? openingAngleDeg;
  final bool? softClose;
  final double? lengthMm;
  final double? loadKg;
  final double? holeSpacingMm;
  final String? colour;
  final bool active;

  /// Whether this hardware item is a hinge.
  bool get isHinge => hardwareType == HardwareType.hinge;

  /// Whether this hardware item is a runner (slide).
  bool get isRunner => hardwareType == HardwareType.runner;

  /// Whether this hardware item is a handle.
  bool get isHandle => hardwareType == HardwareType.handle;

  /// Whether this hardware item is a leg/foot.
  bool get isLeg => hardwareType == HardwareType.leg;

  /// Whether this hardware item is a shelf support.
  bool get isShelfSupport => hardwareType == HardwareType.shelfSupport;

  /// Prominent display title: brand and model if present, with the name.
  String get displayTitle {
    final hasBrand = brand != null && brand!.isNotEmpty;
    final hasModel = model != null && model!.isNotEmpty;

    if (hasBrand && hasModel) {
      return '$brand $model · $name';
    }
    if (hasModel) {
      return '$model · $name';
    }
    if (hasBrand) {
      return '$brand · $name';
    }
    return name;
  }

  /// Formatted opening angle, e.g. "110°".
  String? formattedOpeningAngle(AppLocalizations l10n) {
    final angle = openingAngleDeg;
    if (angle == null) return null;
    final formatted = angle == angle.roundToDouble()
        ? angle.toInt().toString()
        : angle.toString();
    return l10n.hardwareOpeningAngle(formatted);
  }

  /// Formatted cup specification, e.g. "Чашка Ø35×11.3 мм" or "Ø35 мм".
  String? formattedCup(AppLocalizations l10n) {
    final dia = cupDiameterMm;
    final depth = cupDepthMm;
    if (dia == null) return null;

    final diaFormatted = dia == dia.roundToDouble()
        ? dia.toInt().toString()
        : dia.toString();

    if (depth != null) {
      final depthFormatted = depth == depth.roundToDouble()
          ? depth.toInt().toString()
          : depth.toString();
      return l10n.hardwareCupSpec(diaFormatted, depthFormatted);
    }
    return l10n.hardwareCupDiameter(diaFormatted);
  }

  /// Formatted length in mm, e.g. "450 мм".
  String? formattedLength(AppLocalizations l10n) {
    final length = lengthMm;
    if (length == null) return null;
    final formatted = length == length.roundToDouble()
        ? length.toInt().toString()
        : length.toString();
    return l10n.hardwareLength(formatted);
  }

  /// Formatted load capacity, e.g. "до 30 кг".
  String? formattedLoad(AppLocalizations l10n) {
    final load = loadKg;
    if (load == null) return null;
    final formatted = load == load.roundToDouble()
        ? load.toInt().toString()
        : load.toString();
    return l10n.hardwareLoad(formatted);
  }

  /// Formatted handle mounting-hole spacing, e.g. "Межцентровое 128 мм".
  String? formattedHoleSpacing(AppLocalizations l10n) {
    final spacing = holeSpacingMm;
    if (spacing == null) return null;
    final formatted = spacing == spacing.roundToDouble()
        ? spacing.toInt().toString()
        : spacing.toString();
    return l10n.hardwareHoleSpacing(formatted);
  }

  /// Formatted soft-close description, or null if unspecified.
  String? formattedSoftClose(AppLocalizations l10n) {
    if (softClose == null) return null;
    return softClose! ? l10n.hardwareSoftClose : l10n.hardwareNoSoftClose;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hardware_type': hardwareType.code,
    if (brand != null) 'brand': brand,
    if (model != null) 'model': model,
    if (overlay != null) 'overlay': overlay!.code,
    if (cupDiameterMm != null) 'cup_diameter_mm': cupDiameterMm,
    if (cupDepthMm != null) 'cup_depth_mm': cupDepthMm,
    if (mountingSystem != null) 'mounting_system': mountingSystem!.code,
    if (openingAngleDeg != null) 'opening_angle_deg': openingAngleDeg,
    if (softClose != null) 'soft_close': softClose,
    if (lengthMm != null) 'length_mm': lengthMm,
    if (loadKg != null) 'load_kg': loadKg,
    if (holeSpacingMm != null) 'hole_spacing_mm': holeSpacingMm,
    if (colour != null) 'colour': colour,
    'active': active,
  };
}
