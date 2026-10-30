import 'dart:convert';

/// One member of a crew that did a job together: their share in %, or how
/// much of it they made (pieces or m²), or neither — then the server splits
/// equally. One crew uses one way; the server checks it adds up.
typedef CrewShare = ({String user, double? share, double? qty});

/// The crew as the server reads it (`piece_rates._crew`).
String crewJson(List<CrewShare> crew) => jsonEncode([
  for (final member in crew)
    {'user': member.user, 'share': ?member.share, 'qty': ?member.qty},
]);
