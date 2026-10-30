import 'package:meta/meta.dart';

/// One cell of the facade price matrix: milling × finish, ₸ per m².
@immutable
class FacadePrice {
  const FacadePrice({
    required this.milling,
    required this.finish,
    required this.pricePerM2,
    this.enabled = true,
  });

  factory FacadePrice.fromJson(Map<String, dynamic> json) => FacadePrice(
    milling: json['milling'] as String? ?? '',
    finish: json['finish'] as String? ?? '',
    pricePerM2: (json['price_per_m2'] as num?)?.toDouble() ?? 0,
    enabled: json['enabled'] != false,
  );

  final String milling;
  final String finish;
  final double pricePerM2;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is FacadePrice &&
      other.milling == milling &&
      other.finish == finish &&
      other.pricePerM2 == pricePerM2 &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(milling, finish, pricePerM2, enabled);
}

/// The whole matrix, as the server keeps it for this company.
@immutable
class FacadePriceTable {
  const FacadePriceTable({
    required this.finishes,
    required this.prices,
    required this.canEdit,
  });

  factory FacadePriceTable.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'] as List? ?? const [];
    final rawFinishes = json['finishes'] as List? ?? const [];
    return FacadePriceTable(
      finishes: [
        for (final f in rawFinishes)
          if (f is String) f,
      ],
      prices: [
        for (final raw in rawPrices)
          if (raw is Map) FacadePrice.fromJson(Map<String, dynamic>.from(raw)),
      ],
      canEdit: json['can_edit'] == true,
    );
  }

  final List<String> finishes;
  final List<FacadePrice> prices;
  final bool canEdit;

  /// Millings in the order the server sent them, each once.
  List<String> get millings => {for (final p in prices) p.milling}.toList();

  /// The cell, or `null` when the factory does not sell that combination.
  FacadePrice? cell(String milling, String finish) {
    for (final p in prices) {
      if (p.milling == milling && p.finish == finish) return p;
    }
    return null;
  }
}
