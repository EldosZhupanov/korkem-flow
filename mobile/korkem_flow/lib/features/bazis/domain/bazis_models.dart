import 'package:flutter/foundation.dart';

/// Aggregated totals from a Bazis XML export.
@immutable
class BazisTotals {
  const BazisTotals({
    required this.products,
    required this.parts,
    required this.materials,
    required this.operations,
  });

  factory BazisTotals.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic val) => switch (val) {
      final num n => n.toInt(),
      final String s when int.tryParse(s) != null => int.parse(s),
      _ => 0,
    };

    return BazisTotals(
      products: toInt(json['products']),
      parts: toInt(json['parts']),
      materials: toInt(json['materials']),
      operations: toInt(json['operations']),
    );
  }

  final int products;
  final int parts;
  final int materials;
  final int operations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisTotals &&
          runtimeType == other.runtimeType &&
          products == other.products &&
          parts == other.parts &&
          materials == other.materials &&
          operations == other.operations;

  @override
  int get hashCode => Object.hash(products, parts, materials, operations);
}

/// A cut/manufactured part in Bazis (panel, drawer bottom, facade).
@immutable
class BazisPart {
  const BazisPart({
    required this.name,
    this.block,
    this.code,
    this.kind,
    this.length,
    this.width,
    this.thickness,
    this.qty,
    this.edges = const <String>[],
  });

  factory BazisPart.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) => switch (val) {
      final num n => n.toDouble(),
      final String s when double.tryParse(s.replaceAll(',', '.')) != null =>
        double.parse(s.replaceAll(',', '.')),
      _ => null,
    };

    final rawEdges = json['edges'];
    final edgesList = rawEdges is List
        ? rawEdges.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return BazisPart(
      block: json['block']?.toString().trim().isNotEmpty == true
          ? json['block'].toString().trim()
          : null,
      name: '${json['name'] ?? ''}'.trim(),
      code: json['code']?.toString().trim().isNotEmpty == true
          ? json['code'].toString().trim()
          : null,
      kind: json['kind']?.toString().trim().isNotEmpty == true
          ? json['kind'].toString().trim()
          : null,
      length: toDouble(json['length']),
      width: toDouble(json['width']),
      thickness: toDouble(json['thickness']),
      qty: toDouble(json['qty']),
      edges: edgesList,
    );
  }

  /// Structural hierarchy path (section / drawer), e.g. "3 / Шариковые".
  /// This serves as the workshop address for the part.
  final String? block;

  /// Name of the part, e.g. "Боковина левая" or "Полка".
  final String name;

  /// Part position code, e.g. "D-101".
  final String? code;

  /// Object kind, e.g. "Панель".
  final String? kind;

  /// Length in mm.
  final double? length;

  /// Width in mm.
  final double? width;

  /// Thickness in mm.
  final double? thickness;

  /// Quantity of identical parts.
  final double? qty;

  /// Edge band materials attached to the part.
  final List<String> edges;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisPart &&
          runtimeType == other.runtimeType &&
          block == other.block &&
          name == other.name &&
          code == other.code &&
          kind == other.kind &&
          length == other.length &&
          width == other.width &&
          thickness == other.thickness &&
          qty == other.qty &&
          listEquals(edges, other.edges);

  @override
  int get hashCode => Object.hash(
    block,
    name,
    code,
    kind,
    length,
    width,
    thickness,
    qty,
    Object.hashAll(edges),
  );
}

/// A raw material or hardware item in Bazis export.
@immutable
class BazisMaterial {
  const BazisMaterial({
    required this.name,
    this.syncId,
    this.code,
    this.owner,
    this.kind,
    this.unit,
    this.qty,
    this.price,
  });

  factory BazisMaterial.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) => switch (val) {
      final num n => n.toDouble(),
      final String s when double.tryParse(s.replaceAll(',', '.')) != null =>
        double.parse(s.replaceAll(',', '.')),
      _ => null,
    };

    return BazisMaterial(
      syncId: json['sync_id']?.toString().trim().isNotEmpty == true
          ? json['sync_id'].toString().trim()
          : null,
      name: '${json['name'] ?? ''}'.trim(),
      code: json['code']?.toString().trim().isNotEmpty == true
          ? json['code'].toString().trim()
          : null,
      owner: json['owner']?.toString().trim().isNotEmpty == true
          ? json['owner'].toString().trim()
          : null,
      kind: json['kind']?.toString().trim().isNotEmpty == true
          ? json['kind'].toString().trim()
          : null,
      unit: json['unit']?.toString().trim().isNotEmpty == true
          ? json['unit'].toString().trim()
          : null,
      qty: toDouble(json['qty']),
      price: toDouble(json['price']),
    );
  }

  /// Bazis material identity (SyncID or ID or Code).
  final String? syncId;

  /// Material name, e.g. "ЛДСП Дуб Сонома 16мм".
  final String name;

  /// Material catalog code in Bazis.
  final String? code;

  /// Owner element type, e.g. "Панель", "Изделие", "Сборка".
  final String? owner;

  /// Material kind, e.g. "ОсновнойМатериал" or "СопутствующийМатериал".
  final String? kind;

  /// Unit of measurement as exported by Bazis, e.g. "м2", "шт", "пог.м".
  final String? unit;

  /// Calculated quantity (0 or null if Bazis did not compute it).
  final double? qty;

  /// Unit rate / price in Bazis.
  final double? price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisMaterial &&
          runtimeType == other.runtimeType &&
          syncId == other.syncId &&
          name == other.name &&
          code == other.code &&
          owner == other.owner &&
          kind == other.kind &&
          unit == other.unit &&
          qty == other.qty &&
          price == other.price;

  @override
  int get hashCode => Object.hash(
    syncId,
    name,
    code,
    owner,
    kind,
    unit,
    qty,
    price,
  );
}

/// A manufacturing operation in Bazis export (cutting, edging, drilling).
@immutable
class BazisOperation {
  const BazisOperation({
    required this.name,
    this.syncId,
    this.qty,
    this.price,
    this.minutes,
  });

  factory BazisOperation.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) => switch (val) {
      final num n => n.toDouble(),
      final String s when double.tryParse(s.replaceAll(',', '.')) != null =>
        double.parse(s.replaceAll(',', '.')),
      _ => null,
    };

    return BazisOperation(
      syncId: json['sync_id']?.toString().trim().isNotEmpty == true
          ? json['sync_id'].toString().trim()
          : null,
      name: '${json['name'] ?? ''}'.trim(),
      qty: toDouble(json['qty']),
      price: toDouble(json['price']),
      minutes: toDouble(json['minutes']),
    );
  }

  /// SyncID in Bazis if assigned.
  final String? syncId;

  /// Operation name, e.g. "Раскрой" or "Кромление".
  final String name;

  /// Operation quantity / units.
  final double? qty;

  /// Piece rate or cost.
  final double? price;

  /// Labor time in minutes.
  final double? minutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisOperation &&
          runtimeType == other.runtimeType &&
          syncId == other.syncId &&
          name == other.name &&
          qty == other.qty &&
          price == other.price &&
          minutes == other.minutes;

  @override
  int get hashCode => Object.hash(syncId, name, qty, price, minutes);
}

/// A product (furniture unit / project) inside a Bazis export.
@immutable
class BazisProduct {
  const BazisProduct({
    required this.name,
    this.article,
    this.order,
    this.qty,
    this.price,
    this.parts = const <BazisPart>[],
    this.materials = const <BazisMaterial>[],
    this.operations = const <BazisOperation>[],
  });

  factory BazisProduct.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) => switch (val) {
      final num n => n.toDouble(),
      final String s when double.tryParse(s.replaceAll(',', '.')) != null =>
        double.parse(s.replaceAll(',', '.')),
      _ => null,
    };

    final rawParts = json['parts'];
    final rawMaterials = json['materials'];
    final rawOperations = json['operations'];

    return BazisProduct(
      name: '${json['name'] ?? ''}'.trim(),
      article: json['article']?.toString().trim().isNotEmpty == true
          ? json['article'].toString().trim()
          : null,
      order: json['order']?.toString().trim().isNotEmpty == true
          ? json['order'].toString().trim()
          : null,
      qty: toDouble(json['qty']),
      price: toDouble(json['price']),
      parts: rawParts is List
          ? rawParts
                .whereType<Map<String, dynamic>>()
                .map(BazisPart.fromJson)
                .toList(growable: false)
          : const <BazisPart>[],
      materials: rawMaterials is List
          ? rawMaterials
                .whereType<Map<String, dynamic>>()
                .map(BazisMaterial.fromJson)
                .toList(growable: false)
          : const <BazisMaterial>[],
      operations: rawOperations is List
          ? rawOperations
                .whereType<Map<String, dynamic>>()
                .map(BazisOperation.fromJson)
                .toList(growable: false)
          : const <BazisOperation>[],
    );
  }

  /// Product name, e.g. "Кухонный гарнитур «Астана»".
  final String name;

  /// Product article code, e.g. "KG-001".
  final String? article;

  /// Sales order reference if entered in CAD, e.g. "SO-2026-0042".
  final String? order;

  /// Quantity of products in the project.
  final double? qty;

  /// Total product price in Bazis.
  final double? price;

  /// List of parts (panels, fronts, shelves).
  final List<BazisPart> parts;

  /// List of materials and hardware.
  final List<BazisMaterial> materials;

  /// List of manufacturing operations.
  final List<BazisOperation> operations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisProduct &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          article == other.article &&
          order == other.order &&
          qty == other.qty &&
          price == other.price &&
          listEquals(parts, other.parts) &&
          listEquals(materials, other.materials) &&
          listEquals(operations, other.operations);

  @override
  int get hashCode => Object.hash(
    name,
    article,
    order,
    qty,
    price,
    Object.hashAll(parts),
    Object.hashAll(materials),
    Object.hashAll(operations),
  );
}

/// Inspection output from `POST korkem_manufacturing.api.bazis.inspect`.
/// Does not write any records to the database.
@immutable
class BazisInspectResult {
  const BazisInspectResult({
    required this.products,
    required this.totals,
  });

  factory BazisInspectResult.fromJson(Map<String, dynamic> json) {
    final raw = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    final rawProducts = raw['products'];
    final rawTotals = raw['totals'];

    return BazisInspectResult(
      products: rawProducts is List
          ? rawProducts
                .whereType<Map<String, dynamic>>()
                .map(BazisProduct.fromJson)
                .toList(growable: false)
          : const <BazisProduct>[],
      totals: rawTotals is Map<String, dynamic>
          ? BazisTotals.fromJson(rawTotals)
          : const BazisTotals(
              products: 0,
              parts: 0,
              materials: 0,
              operations: 0,
            ),
    );
  }

  final List<BazisProduct> products;
  final BazisTotals totals;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisInspectResult &&
          runtimeType == other.runtimeType &&
          totals == other.totals &&
          listEquals(products, other.products);

  @override
  int get hashCode => Object.hash(totals, Object.hashAll(products));
}

/// One imported product bill of materials result.
@immutable
class BazisImportedProduct {
  const BazisImportedProduct({
    required this.product,
    required this.item,
    required this.bom,
    required this.bomStatus,
    this.materials = const <String>[],
    this.materialsWithoutQuantity = const <String>[],
    this.operations = const <String>[],
    this.operationsAwaitingWorkstation = const <String>[],
    this.salesOrder,
  });

  factory BazisImportedProduct.fromJson(Map<String, dynamic> json) {
    List<String> toStrList(dynamic val) {
      if (val is List) {
        return val.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const <String>[];
    }

    return BazisImportedProduct(
      product: '${json['product'] ?? ''}'.trim(),
      item: '${json['item'] ?? ''}'.trim(),
      bom: '${json['bom'] ?? ''}'.trim(),
      bomStatus: '${json['bom_status'] ?? 'created'}'.trim(),
      materials: toStrList(json['materials']),
      materialsWithoutQuantity: toStrList(json['materials_without_quantity']),
      operations: toStrList(json['operations']),
      operationsAwaitingWorkstation: toStrList(
        json['operations_awaiting_workstation'],
      ),
      salesOrder: json['sales_order']?.toString().trim().isNotEmpty == true
          ? json['sales_order'].toString().trim()
          : null,
    );
  }

  /// Product display name in Bazis.
  final String product;

  /// Item code in ERPNext.
  final String item;

  /// BOM docname in ERPNext (e.g. "BOM-KG-001-001").
  final String bom;

  /// Status of the BOM: "created" (new draft) or "updated" (revised draft).
  final String bomStatus;

  /// Codes of items included as BOM items.
  final List<String> materials;

  /// Materials that had 0 or missing quantity in Bazis and were skipped.
  /// Must be visibly shown to the owner/technologist.
  final List<String> materialsWithoutQuantity;

  /// Names of operations included in routing.
  final List<String> operations;

  /// Operations created in catalog that lack a designated workstation.
  /// Must be visibly shown so the workshop knows routing needs workstation
  /// assignment.
  final List<String> operationsAwaitingWorkstation;

  /// Associated sales order if linked.
  final String? salesOrder;

  bool get isUpdated => bomStatus.toLowerCase() == 'updated';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisImportedProduct &&
          runtimeType == other.runtimeType &&
          product == other.product &&
          item == other.item &&
          bom == other.bom &&
          bomStatus == other.bomStatus &&
          salesOrder == other.salesOrder &&
          listEquals(materials, other.materials) &&
          listEquals(
            materialsWithoutQuantity,
            other.materialsWithoutQuantity,
          ) &&
          listEquals(operations, other.operations) &&
          listEquals(
            operationsAwaitingWorkstation,
            other.operationsAwaitingWorkstation,
          );

  @override
  int get hashCode => Object.hash(
    product,
    item,
    bom,
    bomStatus,
    salesOrder,
    Object.hashAll(materials),
    Object.hashAll(materialsWithoutQuantity),
    Object.hashAll(operations),
    Object.hashAll(operationsAwaitingWorkstation),
  );
}

/// Output from `POST korkem_manufacturing.api.bazis.import_specification`.
@immutable
class BazisImportResult {
  const BazisImportResult({
    required this.totals,
    required this.products,
    this.company,
  });

  factory BazisImportResult.fromJson(Map<String, dynamic> json) {
    final raw = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    final rawTotals = raw['totals'];
    final rawProducts = raw['products'];

    return BazisImportResult(
      company: raw['company']?.toString().trim(),
      totals: rawTotals is Map<String, dynamic>
          ? BazisTotals.fromJson(rawTotals)
          : const BazisTotals(
              products: 0,
              parts: 0,
              materials: 0,
              operations: 0,
            ),
      products: rawProducts is List
          ? rawProducts
                .whereType<Map<String, dynamic>>()
                .map(BazisImportedProduct.fromJson)
                .toList(growable: false)
          : const <BazisImportedProduct>[],
    );
  }

  final String? company;
  final BazisTotals totals;
  final List<BazisImportedProduct> products;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BazisImportResult &&
          runtimeType == other.runtimeType &&
          company == other.company &&
          totals == other.totals &&
          listEquals(products, other.products);

  @override
  int get hashCode => Object.hash(
    company,
    totals,
    Object.hashAll(products),
  );
}
