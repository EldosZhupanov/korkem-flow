/// An order's and a customer's tags (`korkem_manufacturing.services.mdf_tags`).
///
/// An order's are set in its head; a customer's in the customer list, and
/// they show on all that customer's orders.
enum MdfOrderTag {
  urgent('urgent'),
  rework('rework'),
  warranty('warranty'),

  /// The customer brings his own paint (owner, 14.11.2026).
  clientPaint('client_paint'),

  /// The customer brings his own PVC film: pressed here, none from our shelf.
  clientFilm('client_film'),

  /// The customer brings his own facades: sanded and painted here, not cut.
  clientParts('client_parts');

  const MdfOrderTag(this.wire);
  final String wire;

  /// Set from a coating group's head rather than the order's.
  bool get byGroup =>
      this == clientPaint || this == clientFilm || this == clientParts;

  static List<MdfOrderTag> parse(Object? raw) => [
    for (final t in values)
      if (raw is List && raw.contains(t.wire)) t,
  ];
}

enum MdfCustomerTag {
  vip('vip'),
  furnitureMaker('furniture_maker'),
  newcomer('new'),
  prepayOnly('prepay_only');

  const MdfCustomerTag(this.wire);
  final String wire;

  static List<MdfCustomerTag> parse(Object? raw) => [
    for (final t in values)
      if (raw is List && raw.contains(t.wire)) t,
  ];
}
