import 'dart:math' as math;

import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';

// The rules of a layout made by hand (owner, 12.11.2026) — the same the
// server checks before it keeps one: on the table, a gap apart, inside a
// section of film.

/// How near to a neighbour's line a dragged part jumps onto it, mm.
const double pressSnapMm = 40;

/// The step a free place is looked for with, mm.
const double _scanMm = 10;

/// The longest working length the press has a section of film for.
double pressLongest(PressSettings press) => press.sections.isEmpty
    ? press.lengthMm
    : press.sections.map((s) => s.lengthMm).reduce(math.max);

/// The part at another place.
PlacedPart pressMoved(PlacedPart p, double x, double y) => PlacedPart(
  pos: p.pos,
  x: x,
  y: y,
  width: p.width,
  height: p.height,
  rotated: p.rotated,
);

/// The part turned a quarter: its sides swap.
PlacedPart pressTurned(PlacedPart p) => PlacedPart(
  pos: p.pos,
  x: p.x,
  y: p.y,
  width: p.height,
  height: p.width,
  rotated: !p.rotated,
);

bool _apart(PlacedPart a, PlacedPart b, double gap) =>
    a.x >= b.x + b.width + gap ||
    b.x >= a.x + a.width + gap ||
    a.y >= b.y + b.height + gap ||
    b.y >= a.y + a.height + gap;

bool _onTable(PlacedPart p, PressSettings press) =>
    p.x >= press.marginMm &&
    p.y >= press.marginMm &&
    p.y + p.height <= press.widthMm - press.marginMm &&
    p.x + p.width <= pressLongest(press) - press.marginMm;

/// Which parts of a load may not lie as they do: off the table, or nearer
/// to another than the gap. By index.
Set<int> pressClashes(List<PlacedPart> placed, PressSettings press) {
  final bad = <int>{};
  for (var i = 0; i < placed.length; i++) {
    if (!_onTable(placed[i], press)) bad.add(i);
    for (var j = i + 1; j < placed.length; j++) {
      if (!_apart(placed[i], placed[j], press.gapMm)) {
        bad
          ..add(i)
          ..add(j);
      }
    }
  }
  return bad;
}

/// The section of film a load takes: the shortest that holds its parts —
/// or a longer one, when [asked]. Null when no section is long enough.
({double filmM, double lengthMm})? pressSection(
  List<PlacedPart> placed,
  PressSettings press, {
  double? asked,
}) {
  final reach = placed.isEmpty
      ? 0.0
      : placed.map((p) => p.x + p.width).reduce(math.max) + press.marginMm;
  final need = math.max(reach, asked ?? 0.0);
  final sections = [...press.sections]
    ..sort((a, b) => a.lengthMm.compareTo(b.lengthMm));
  for (final s in sections) {
    if (s.lengthMm >= need) return s;
  }
  return null;
}

double? _nearest(double value, Iterable<double> lines) {
  double? best;
  for (final line in lines) {
    final d = (line - value).abs();
    if (d <= pressSnapMm && (best == null || d < (best - value).abs())) {
      best = line;
    }
  }
  return best;
}

/// A dragged part let go: kept on the table, and pulled onto the nearest
/// line — the table's margin, or exactly the gap from a neighbour.
PlacedPart pressSnapped(
  PlacedPart p,
  List<PlacedPart> others,
  PressSettings press,
) {
  final maxX = math.max(
    press.marginMm,
    pressLongest(press) - press.marginMm - p.width,
  );
  final maxY = math.max(
    press.marginMm,
    press.widthMm - press.marginMm - p.height,
  );
  final x =
      _nearest(p.x, [
        press.marginMm,
        for (final o in others) ...[
          o.x + o.width + press.gapMm,
          o.x - press.gapMm - p.width,
          o.x,
        ],
      ]) ??
      p.x;
  final y =
      _nearest(p.y, [
        press.marginMm,
        maxY,
        for (final o in others) ...[
          o.y + o.height + press.gapMm,
          o.y - press.gapMm - p.height,
          o.y,
        ],
      ]) ??
      p.y;
  return pressMoved(
    p,
    math.min(math.max(x, press.marginMm), maxX).roundToDouble(),
    math.min(math.max(y, press.marginMm), maxY).roundToDouble(),
  );
}

/// The first free place for a part among [others], from the table's corner
/// along its length. No room — the corner, where it shows as a clash.
PlacedPart pressFreeSpot(
  PlacedPart p,
  List<PlacedPart> others,
  PressSettings press,
) {
  final maxX = pressLongest(press) - press.marginMm - p.width;
  final maxY = press.widthMm - press.marginMm - p.height;
  for (var x = press.marginMm; x <= maxX; x += _scanMm) {
    for (var y = press.marginMm; y <= maxY; y += _scanMm) {
      final at = pressMoved(p, x, y);
      if (others.every((o) => _apart(at, o, press.gapMm))) return at;
    }
  }
  return pressMoved(p, press.marginMm, press.marginMm);
}
