import 'package:meta/meta.dart';

/// Who sees money in this company, as the server decided it.
///
/// The app never decides this itself: it only draws what it was sent. A
/// worker's phone receives `null` instead of a price — this object only says
/// whether the switch exists for the person looking and where it stands.
@immutable
class PriceVisibility {
  const PriceVisibility({
    required this.floorSeesPrices,
    required this.youSeePrices,
    required this.canChange,
  });

  factory PriceVisibility.fromJson(Map<String, dynamic> json) {
    return PriceVisibility(
      floorSeesPrices: json['floor_sees_prices'] == true,
      youSeePrices: json['you_see_prices'] == true,
      canChange: json['can_change'] == true,
    );
  }

  /// The administrator's switch: may the shop floor, warehouse and drivers
  /// see client prices and order totals.
  final bool floorSeesPrices;

  /// Whether the person asking sees money.
  final bool youSeePrices;

  /// Only the administrator may flip the switch.
  final bool canChange;

  @override
  bool operator ==(Object other) =>
      other is PriceVisibility &&
      other.floorSeesPrices == floorSeesPrices &&
      other.youSeePrices == youSeePrices &&
      other.canChange == canChange;

  @override
  int get hashCode => Object.hash(floorSeesPrices, youSeePrices, canChange);
}
