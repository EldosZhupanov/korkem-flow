import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';

/// How deep [tool] cuts at [d] mm from the centre of its path when the path
/// runs [depth] mm below the face — the cutter's own shape, turned into the
/// groove it leaves (owner, 20.11.2026: «разрез и 3D, как в Tez3D»).
///
/// A V-cutter leaves a wedge, a ball-nose a round trough, a straight one a
/// flat-bottomed slot. Without a card for the tool the cut is taken as a slot
/// as wide as the server said it is.
double cncCutAt(CncTool? tool, double depth, double width, double d) {
  if (depth <= 0) return 0;
  final r = tool == null ? width / 2 : tool.diameter / 2;
  if (d >= r) return 0;
  switch (tool?.kind) {
    case CncToolKind.v:
      final slope = tan(tool!.angle.clamp(10, 170) * pi / 360);
      return max<double>(0, depth - d / slope);
    case CncToolKind.ball:
      return max<double>(0, depth - r + sqrt(r * r - d * d));
    case CncToolKind.flat:
    case null:
      return depth;
  }
}

/// The depth a cut runs at: the server's, else read back off the width it
/// leaves (an older server sent the width alone).
double cncDepthOf(CncCut c, CncTool? tool) {
  if (c.depth > 0) return c.depth;
  if (tool == null) return 0;
  return switch (tool.kind) {
    CncToolKind.v => c.width / 2 / tan(tool.angle.clamp(10, 170) * pi / 360),
    CncToolKind.ball => tool.diameter / 2,
    CncToolKind.flat => 1,
  };
}

double _toSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// One straight piece of a cut, with the cutter that runs along it.
typedef _Piece = ({Offset a, Offset b, CncTool? tool, double depth, double w});

List<_Piece> _pieces(List<CncCut> cuts, Map<String, CncTool> tools) => [
  for (final c in cuts)
    if (c.points.length > 1) ...[
      for (var i = 1; i < c.points.length; i++)
        (
          a: c.points[i - 1],
          b: c.points[i],
          tool: tools[c.tool],
          depth: cncDepthOf(c, tools[c.tool]),
          w: c.width,
        ),
      if (c.closed && c.points.first != c.points.last)
        (
          a: c.points.last,
          b: c.points.first,
          tool: tools[c.tool],
          depth: cncDepthOf(c, tools[c.tool]),
          w: c.width,
        ),
    ],
];

double _reach(_Piece p) => p.tool == null ? p.w / 2 : p.tool!.diameter / 2;

/// A facade's face after the router, as depths on a square grid — what the
/// 3D view draws and the section reads.
class CncRelief {
  CncRelief._(this.width, this.height, this.step, this.cols, this.rows)
    : depths = Float32List((cols + 1) * (rows + 1));

  /// Cuts on a facade [width] × [height] mm, sampled on a grid of no more
  /// than about [nodes] points (fine enough to see a V-groove's walls on a
  /// kitchen door, coarse enough to turn it smoothly).
  factory CncRelief.of({
    required double width,
    required double height,
    required List<CncCut> cuts,
    required Map<String, CncTool> tools,
    int nodes = 50000,
  }) {
    final w = max<double>(1, width);
    final h = max<double>(1, height);
    final step = max(0.8, sqrt(w * h / nodes));
    final cols = max(1, (w / step).ceil());
    final rows = max(1, (h / step).ceil());
    final r = CncRelief._(w, h, step, cols, rows);
    for (final p in _pieces(cuts, tools)) {
      final reach = _reach(p);
      final x0 = ((min(p.a.dx, p.b.dx) - reach) / step).floor().clamp(0, cols);
      final x1 = ((max(p.a.dx, p.b.dx) + reach) / step).ceil().clamp(0, cols);
      final y0 = ((min(p.a.dy, p.b.dy) - reach) / step).floor().clamp(0, rows);
      final y1 = ((max(p.a.dy, p.b.dy) + reach) / step).ceil().clamp(0, rows);
      for (var j = y0; j <= y1; j++) {
        for (var i = x0; i <= x1; i++) {
          final d = _toSegment(
            Offset(min(i * step, w), min(j * step, h)),
            p.a,
            p.b,
          );
          final z = cncCutAt(p.tool, p.depth, p.w, d);
          final k = j * (cols + 1) + i;
          if (z > r.depths[k]) r.depths[k] = z;
        }
      }
    }
    return r;
  }

  final double width;
  final double height;

  /// Between grid points, mm.
  final double step;
  final int cols;
  final int rows;

  /// Below the face at grid point (i, j), row by row from the bottom edge.
  final Float32List depths;

  double at(int i, int j) => depths[j.clamp(0, rows) * (cols + 1) + i.clamp(0, cols)];

  /// Where the grid point lies on the facade, mm (the far ones clamped to the
  /// edge rather than a step past it).
  double x(int i) => min(i * step, width);
  double y(int j) => min(j * step, height);

  double get deepest => depths.isEmpty ? 0 : depths.reduce(max);
}

/// The facade cut across, from its left edge towards the middle, at
/// mid-height — the yellow profile of the milling world.
class CncSection {
  CncSection._(this.step, this.depths);

  /// Sampled every [step] mm; exact, not read off the 3D grid.
  factory CncSection.of({
    required double width,
    required double height,
    required List<CncCut> cuts,
    required Map<String, CncTool> tools,
    double step = 0.25,
  }) {
    final pieces = _pieces(cuts, tools);
    final half = max(step, width / 2);
    final n = (half / step).ceil();
    final out = Float32List(n + 1);
    for (var k = 0; k <= n; k++) {
      final at = Offset(min(k * step, half), height / 2);
      var z = 0.0;
      for (final p in pieces) {
        final reach = _reach(p);
        if (at.dx < min(p.a.dx, p.b.dx) - reach ||
            at.dx > max(p.a.dx, p.b.dx) + reach ||
            at.dy < min(p.a.dy, p.b.dy) - reach ||
            at.dy > max(p.a.dy, p.b.dy) + reach) {
          continue;
        }
        z = max(z, cncCutAt(p.tool, p.depth, p.w, _toSegment(at, p.a, p.b)));
      }
      out[k] = z;
    }
    return CncSection._(step, out);
  }

  final double step;

  /// Below the face, every [step] mm from the edge.
  final Float32List depths;

  double get deepest => depths.isEmpty ? 0 : depths.reduce(max);

  /// From the edge to the first cut and to the last, mm; null with no cut.
  (double, double)? get span {
    int? first;
    int? last;
    for (var k = 0; k < depths.length; k++) {
      if (depths[k] <= 0.01) continue;
      first ??= k;
      last = k;
    }
    if (first == null) return null;
    return (first * step, last! * step);
  }
}
