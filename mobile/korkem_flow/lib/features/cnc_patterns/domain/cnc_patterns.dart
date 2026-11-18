import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(Object? v) => v == null ? null : _d(v);
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in v is List ? v : const <Object>[])
    if (r is Map) Map<String, dynamic>.from(r),
];
List<String> _strings(Object? v) => [
  for (final s in v is List ? v : const <Object>[]) '$s',
];

/// The cutter's shape: V-shaped, round-nosed, straight.
enum CncToolKind {
  v('v'),
  ball('ball'),
  flat('flat');

  const CncToolKind(this.wire);

  final String wire;

  static CncToolKind of(Object? wire) =>
      values.firstWhere((k) => k.wire == '$wire', orElse: () => CncToolKind.v);
}

/// A cutter of the library (owner, 18.11.2026).
@immutable
class CncTool {
  const CncTool({
    required this.name,
    this.kind = CncToolKind.v,
    this.diameter = 12,
    this.angle = 90,
    this.feed = 3000,
    this.plunge = 1000,
    this.rpm = 18000,
    this.passDepth = 3,
  });

  factory CncTool.fromJson(Map<String, dynamic> j) => CncTool(
    name: '${j['name'] ?? ''}',
    kind: CncToolKind.of(j['kind']),
    diameter: _d(j['diameter']),
    angle: _d(j['angle']),
    feed: _d(j['feed']),
    plunge: _d(j['plunge']),
    rpm: _d(j['rpm']),
    passDepth: _d(j['pass_depth']),
  );

  final String name;
  final CncToolKind kind;
  final double diameter;
  final double angle;
  final double feed;
  final double plunge;
  final double rpm;
  final double passDepth;
}

/// What an element of a pattern is.
enum CncElementKind {
  frame('frame'),
  arch('arch'),
  grooves('grooves');

  const CncElementKind(this.wire);

  final String wire;

  static CncElementKind of(Object? v) =>
      values.firstWhere((k) => k.wire == '$v', orElse: () => frame);
}

/// A frame's corner: square, rounded, cut inward.
enum CncCorner {
  square('square'),
  round('round'),
  cove('cove');

  const CncCorner(this.wire);

  final String wire;

  static CncCorner of(Object? v) =>
      values.firstWhere((k) => k.wire == '$v', orElse: () => square);
}

/// One part of a pattern: a frame, an arch or grooves, with its cutter and
/// depth; the sizes measured from the facade's edges.
@immutable
class CncElement {
  const CncElement({
    required this.kind,
    required this.tool,
    this.depth = 3,
    this.offset = 60,
    this.corner = CncCorner.square,
    this.radius = 0,
    this.rise = 80,
    this.vertical = true,
    this.step = 30,
    this.side = 0,
    this.ends = 0,
  });

  factory CncElement.fromJson(Map<String, dynamic> j) => CncElement(
    kind: CncElementKind.of(j['kind']),
    tool: '${j['tool'] ?? ''}',
    depth: _d(j['depth'] ?? 3),
    offset: _d(j['offset'] ?? 60),
    corner: CncCorner.of(j['corner']),
    radius: _d(j['radius']),
    rise: _d(j['rise'] ?? 80),
    vertical: j['direction'] != 'horizontal',
    step: _d(j['step'] ?? 30),
    side: _d(j['side']),
    ends: _d(j['ends']),
  );

  final CncElementKind kind;
  final String tool;
  final double depth;
  final double offset;
  final CncCorner corner;
  final double radius;
  final double rise;
  final bool vertical;
  final double step;
  final double side;
  final double ends;

  CncElement copyWith({
    CncElementKind? kind,
    String? tool,
    double? depth,
    double? offset,
    CncCorner? corner,
    double? radius,
    double? rise,
    bool? vertical,
    double? step,
    double? side,
    double? ends,
  }) => CncElement(
    kind: kind ?? this.kind,
    tool: tool ?? this.tool,
    depth: depth ?? this.depth,
    offset: offset ?? this.offset,
    corner: corner ?? this.corner,
    radius: radius ?? this.radius,
    rise: rise ?? this.rise,
    vertical: vertical ?? this.vertical,
    step: step ?? this.step,
    side: side ?? this.side,
    ends: ends ?? this.ends,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'tool': tool,
    'depth': depth,
    ...switch (kind) {
      CncElementKind.frame => {
        'offset': offset,
        'corner': corner.wire,
        'radius': corner == CncCorner.square ? 0 : radius,
      },
      CncElementKind.arch => {'offset': offset, 'rise': rise},
      CncElementKind.grooves => {
        'direction': vertical ? 'vertical' : 'horizontal',
        'step': step,
        'side': side,
        'ends': ends,
      },
    },
  };
}

/// A pattern: its elements, the milling it cuts, the smallest facade it
/// fits and the pattern for smaller ones.
@immutable
class CncPattern {
  const CncPattern({
    required this.name,
    required this.elements,
    this.milling,
    this.minW = 0,
    this.minH = 0,
    this.fallback,
    this.example = false,
  });

  factory CncPattern.fromJson(Map<String, dynamic> j) => CncPattern(
    name: '${j['name'] ?? ''}',
    milling: _s(j['milling']),
    minW: _d(j['min_w']),
    minH: _d(j['min_h']),
    fallback: _s(j['fallback']),
    example: j['example'] == true,
    elements: [for (final e in _rows(j['elements'])) CncElement.fromJson(e)],
  );

  final String name;
  final String? milling;
  final double minW;
  final double minH;
  final String? fallback;
  final bool example;
  final List<CncElement> elements;
}

/// How the router wants its program.
@immutable
class CncMachine {
  const CncMachine({
    this.ext = 'nc',
    this.comments = true,
    this.arcs = true,
    this.lineNumbers = false,
    this.swapXy = false,
    this.safeZ = 20,
    this.clearZ = 3,
    this.rapid = 6000,
    this.dwell = 0,
  });

  factory CncMachine.fromJson(Map<String, dynamic> j) => CncMachine(
    ext: '${j['ext'] ?? 'nc'}',
    comments: j['comments'] != false,
    arcs: j['arcs'] != false,
    lineNumbers: j['line_numbers'] == true,
    swapXy: j['swap_xy'] == true,
    safeZ: _d(j['safe_z'] ?? 20),
    clearZ: _d(j['clear_z'] ?? 3),
    rapid: _d(j['rapid'] ?? 6000),
    dwell: _d(j['dwell']),
  );

  final String ext;
  final bool comments;
  final bool arcs;
  final bool lineNumbers;
  final bool swapXy;
  final double safeZ;
  final double clearZ;
  final double rapid;
  final double dwell;

  Map<String, Object?> toJson() => {
    'ext': ext,
    'comments': comments ? 1 : 0,
    'arcs': arcs ? 1 : 0,
    'line_numbers': lineNumbers ? 1 : 0,
    'swap_xy': swapXy ? 1 : 0,
    'safe_z': safeZ,
    'clear_z': clearZ,
    'rapid': rapid,
    'dwell': dwell,
  };
}

/// A person the owner may let see the module.
typedef CncPerson = ({String user, String name});

/// The switch, and — when on — the library.
@immutable
class CncStatus {
  const CncStatus({
    required this.enabled,
    required this.visible,
    required this.canManage,
    this.users = const [],
    this.people = const [],
    this.tools = const [],
    this.patterns = const [],
    this.machine = const CncMachine(),
    this.millings = const [],
  });

  factory CncStatus.fromJson(Map<String, dynamic> j) => CncStatus(
    enabled: j['enabled'] == true,
    visible: j['visible'] == true,
    canManage: j['can_manage'] == true,
    users: _strings(j['users']),
    people: [
      for (final p in _rows(j['people']))
        (user: '${p['user']}', name: '${p['name'] ?? p['user']}'),
    ],
    tools: [for (final t in _rows(j['tools'])) CncTool.fromJson(t)],
    patterns: [for (final p in _rows(j['patterns'])) CncPattern.fromJson(p)],
    machine: j['machine'] is Map
        ? CncMachine.fromJson(Map<String, dynamic>.from(j['machine'] as Map))
        : const CncMachine(),
    millings: _strings(j['millings']),
  );

  final bool enabled;
  final bool visible;
  final bool canManage;
  final List<String> users;
  final List<CncPerson> people;
  final List<CncTool> tools;
  final List<CncPattern> patterns;
  final CncMachine machine;
  final List<String> millings;
}

/// One cut to draw: its points (mm, origin bottom-left) and the width it
/// leaves on the face.
@immutable
class CncCut {
  const CncCut({
    required this.tool,
    required this.width,
    required this.closed,
    required this.points,
  });

  factory CncCut.fromJson(Map<String, dynamic> j) => CncCut(
    tool: '${j['tool'] ?? ''}',
    width: _d(j['width']),
    closed: j['closed'] == true,
    points: [
      for (final p in j['points'] is List ? j['points'] as List : const [])
        if (p is List && p.length == 2) Offset(_d(p[0]), _d(p[1])),
    ],
  );

  final String tool;
  final double width;
  final bool closed;
  final List<Offset> points;
}

/// A program, its file name when it is an order's.
@immutable
class CncFile {
  const CncFile({
    required this.text,
    this.tool,
    this.name,
    this.qty,
    this.minutes = 0,
    this.cutM = 0,
    this.passes = 0,
  });

  factory CncFile.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] is Map
        ? Map<String, dynamic>.from(j['stats'] as Map)
        : const <String, dynamic>{};
    return CncFile(
      text: '${j['text'] ?? ''}',
      tool: _s(j['tool']),
      name: _s(j['name']),
      qty: _dn(j['qty']),
      minutes: _d(j['minutes'] ?? stats['minutes']),
      cutM: _d(stats['cut_m']),
      passes: _d(stats['passes']).round(),
    );
  }

  final String text;
  final String? tool;
  final String? name;
  final double? qty;
  final double minutes;
  final double cutM;
  final int passes;
}

/// A pattern on a facade of one size.
@immutable
class CncPreview {
  const CncPreview({
    this.pattern,
    this.example = false,
    this.error,
    this.warnings = const [],
    this.cuts = const [],
    this.files = const [],
    this.minutes = 0,
    this.ext = 'nc',
  });

  factory CncPreview.fromJson(Map<String, dynamic> j) => CncPreview(
    pattern: _s(j['pattern']),
    example: j['example'] == true,
    error: _s(j['error']),
    warnings: _strings(j['warnings']),
    cuts: [for (final c in _rows(j['paths'])) CncCut.fromJson(c)],
    files: [for (final f in _rows(j['files'])) CncFile.fromJson(f)],
    minutes: _d(j['minutes']),
    ext: '${j['ext'] ?? 'nc'}',
  );

  final String? pattern;
  final bool example;
  final String? error;
  final List<String> warnings;
  final List<CncCut> cuts;
  final List<CncFile> files;
  final double minutes;
  final String ext;
}

/// An order's position as the router sees it.
@immutable
class CncOrderLine {
  const CncOrderLine({
    required this.line,
    required this.no,
    required this.height,
    required this.width,
    required this.qty,
    this.milling,
    this.pattern,
    this.error,
    this.warnings = const [],
    this.minutes,
  });

  factory CncOrderLine.fromJson(Map<String, dynamic> j) => CncOrderLine(
    line: '${j['line']}',
    no: _d(j['no']).round(),
    height: _d(j['height']),
    width: _d(j['width']),
    qty: _d(j['qty']),
    milling: _s(j['milling']),
    pattern: _s(j['pattern']),
    error: _s(j['error']),
    warnings: _strings(j['warnings']),
    minutes: _dn(j['minutes']),
  );

  final String line;
  final int no;
  final double height;
  final double width;
  final double qty;
  final String? milling;
  final String? pattern;
  final String? error;
  final List<String> warnings;
  final double? minutes;

  bool get ready => pattern != null && error == null;
}

/// An order's positions for the router.
@immutable
class CncOrderPlan {
  const CncOrderPlan({
    required this.order,
    required this.lines,
    this.minutes = 0,
  });

  factory CncOrderPlan.fromJson(Map<String, dynamic> j) => CncOrderPlan(
    order: '${j['order'] ?? ''}',
    lines: [for (final l in _rows(j['lines'])) CncOrderLine.fromJson(l)],
    minutes: _d(j['minutes']),
  );

  final String order;
  final List<CncOrderLine> lines;
  final double minutes;
}
