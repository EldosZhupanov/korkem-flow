import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_relief.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The facade in 3D, its grooves cut as the cutters leave them, turned with
/// the mouse or a finger (owner, 20.11.2026: «3д чтобы видеть его»).
///
/// Drawn by hand on the canvas — a lit height-field, painted back to front —
/// rather than through a 3D package: nothing to install on the shop's
/// machines and nothing that breaks on an old graphics card.
class CncFacade3d extends StatefulWidget {
  const CncFacade3d({
    required this.relief,
    required this.thickness,
    this.colour = AppColors.facadeBare,
    super.key,
  });

  final CncRelief relief;

  /// The board, mm.
  final double thickness;

  /// The film's or the paint's colour; primed MDF when none is chosen.
  final Color colour;

  @override
  State<CncFacade3d> createState() => _CncFacade3dState();
}

typedef _Look = ({double yaw, double pitch});

class _CncFacade3dState extends State<CncFacade3d> {
  static const _Look _tilted = (yaw: -0.45, pitch: 0.35);
  static const _Look _front = (yaw: 0, pitch: 0);
  static const _Look _side = (yaw: -1.15, pitch: 0.12);
  static const double _limit = 1.35;

  _Look _look = _tilted;
  Int32List? _shade;
  CncRelief? _shadeOf;
  Color? _shadeIn;

  Int32List _shading() {
    if (_shade != null &&
        identical(_shadeOf, widget.relief) &&
        _shadeIn == widget.colour) {
      return _shade!;
    }
    _shadeOf = widget.relief;
    _shadeIn = widget.colour;
    return _shade = cncShade(widget.relief, widget.colour);
  }

  void _turn(Offset delta) => setState(
    () => _look = (
      yaw: (_look.yaw + delta.dx * 0.01).clamp(-_limit, _limit),
      pitch: (_look.pitch + delta.dy * 0.01).clamp(-_limit, _limit),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget view(String key, String label, _Look look) => TextButton(
      key: ValueKey(key),
      onPressed: () => setState(() => _look = look),
      child: Text(label),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('cnc3dTurn'),
            onPanUpdate: (d) => _turn(d.delta),
            child: CustomPaint(
              painter: _ReliefPainter(
                relief: widget.relief,
                thickness: widget.thickness,
                shade: _shading(),
                colour: widget.colour,
                yaw: _look.yaw,
                pitch: _look.pitch,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Wrap(
            children: [
              view('cnc3dFront', l10n.cncp3dFront, _front),
              view('cnc3dSide', l10n.cncp3dSide, _side),
              view('cnc3dTilt', l10n.cncp3dTilt, _tilted),
            ],
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Text(
            l10n.cncp3dHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

int _argb(double r, double g, double b) =>
    (0xFF << 24) |
    ((r * 255).round().clamp(0, 255) << 16) |
    ((g * 255).round().clamp(0, 255) << 8) |
    (b * 255).round().clamp(0, 255);

/// [c] lit by [k]: below 1 towards the shadow, above 1 towards a highlight.
int _lit(Color c, double k) {
  if (k <= 1) return _argb(c.r * k, c.g * k, c.b * k);
  final t = min<double>(1, (k - 1) * 1.5);
  return _argb(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t);
}

/// Every grid point's colour under a light from the upper left, the flat
/// face exactly [colour]: walls turned to the light brighter, away darker,
/// the bottom of a deep groove a little darker still.
Int32List cncShade(CncRelief r, Color colour) {
  const lx = -0.45;
  const ly = 0.55;
  const lz = 0.70;
  final ll = sqrt(lx * lx + ly * ly + lz * lz);
  const ambient = 0.35;
  final flat = ambient + (1 - ambient) * lz / ll;
  final out = Int32List((r.cols + 1) * (r.rows + 1));
  for (var j = 0; j <= r.rows; j++) {
    for (var i = 0; i <= r.cols; i++) {
      // The face is z = -depth, so its normal leans along the depth's rise.
      final gx = (r.at(i + 1, j) - r.at(i - 1, j)) / (2 * r.step);
      final gy = (r.at(i, j + 1) - r.at(i, j - 1)) / (2 * r.step);
      final nl = sqrt(gx * gx + gy * gy + 1);
      final ndl = max<double>(0, (gx * lx + gy * ly + lz) / (nl * ll));
      var k = (ambient + (1 - ambient) * ndl) / flat;
      k *= 1 - min(0.15, 0.02 * r.at(i, j));
      out[j * (r.cols + 1) + i] = _lit(colour, k);
    }
  }
  return out;
}

class _ReliefPainter extends CustomPainter {
  _ReliefPainter({
    required this.relief,
    required this.thickness,
    required this.shade,
    required this.colour,
    required this.yaw,
    required this.pitch,
  });

  final CncRelief relief;
  final double thickness;
  final Int32List shade;
  final Color colour;
  final double yaw;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final r = relief;
    final w = r.width;
    final h = r.height;
    final t = max(1, thickness).toDouble();
    final span = max(w, h);
    final scale = 0.8 * min(size.width, size.height) / span;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final cy0 = cos(yaw);
    final sy0 = sin(yaw);
    final cp = cos(pitch);
    final sp = sin(pitch);
    final camera = 3 * span;

    // Millimetres about the facade's centre, the face at z = 0, the camera
    // out in front; the yaw turns it about its height, the pitch tips it.
    (double, double, double) turn(double x, double y, double z) {
      final x1 = x * cy0 + z * sy0;
      final z1 = -x * sy0 + z * cy0;
      return (x1, y * cp - z1 * sp, y * sp + z1 * cp);
    }

    Offset project(double x, double y, double z) {
      final (x1, y2, z2) = turn(x - w / 2, y - h / 2, z);
      final f = camera / (camera - z2);
      return Offset(cx + x1 * f * scale, cy - y2 * f * scale);
    }

    bool facing(double nx, double ny, double nz) {
      final z1 = -nx * sy0 + nz * cy0;
      return ny * sp + z1 * cp > 0;
    }

    // The board's edges that face the camera, first: they lie behind the
    // face wherever the two overlap.
    final edge = Paint()..style = PaintingStyle.fill;
    void side(List<(double, double)> at, double nx, double ny, double k) {
      if (!facing(nx, ny, 0)) return;
      final path = Path();
      for (final (i, (x, y)) in at.indexed) {
        final top = project(x, y, 0);
        if (i == 0) {
          path.moveTo(top.dx, top.dy);
        } else {
          path.lineTo(top.dx, top.dy);
        }
      }
      for (final (x, y) in at.reversed) {
        final back = project(x, y, -t);
        path.lineTo(back.dx, back.dy);
      }
      canvas.drawPath(path..close(), edge..color = Color(_lit(colour, k)));
    }

    side([(0, 0), (0, h)], -1, 0, 0.82);
    side([(w, 0), (w, h)], 1, 0, 0.7);
    side([(0, 0), (w, 0)], 0, -1, 0.66);
    side([(0, h), (w, h)], 0, 1, 0.92);

    final cols = r.cols;
    final rows = r.rows;
    final stride = cols + 1;
    final positions = Float32List(stride * (rows + 1) * 2);
    for (var j = 0; j <= rows; j++) {
      for (var i = 0; i <= cols; i++) {
        final p = project(r.x(i), r.y(j), -r.at(i, j));
        final k = (j * stride + i) * 2;
        positions[k] = p.dx;
        positions[k + 1] = p.dy;
      }
    }
    // Back to front: the far rows and the far columns first, so a groove's
    // near wall is laid over its far one.
    final rowsUp = sp > 0;
    final colsUp = sy0 <= 0;
    final indices = Uint16List(cols * rows * 6);
    var n = 0;
    for (var jj = 0; jj < rows; jj++) {
      final j = rowsUp ? jj : rows - 1 - jj;
      for (var ii = 0; ii < cols; ii++) {
        final i = colsUp ? ii : cols - 1 - ii;
        final a = j * stride + i;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        indices
          ..[n++] = a
          ..[n++] = b
          ..[n++] = d
          ..[n++] = a
          ..[n++] = d
          ..[n++] = c;
      }
    }
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        colors: shade,
        indices: indices,
      ),
      BlendMode.dst,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_ReliefPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      !identical(old.relief, relief) ||
      !identical(old.shade, shade) ||
      old.thickness != thickness ||
      old.colour != colour;
}

/// The section, at one to one: the board in yellow, each cutter's groove
/// taken out of its face, from the edge to just past the last cut.
class CncSectionView extends StatelessWidget {
  const CncSectionView({
    required this.section,
    required this.thickness,
    super.key,
  });

  final CncSection section;
  final double thickness;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final t = max(1, thickness).toDouble();
      final all = (section.depths.length - 1) * section.step;
      final span = section.span;
      final end = min(
        all,
        max(t * 3, (span?.$2 ?? all) + AppSpacing.xl),
      ).clamp(section.step, double.infinity);
      final scale = box.maxWidth / end;
      // One to one, but never so thin it cannot be read nor so tall it
      // pushes the rest away.
      final height = (t * scale).clamp(AppSpacing.xl, AppSpacing.xxxl * 3);
      return SizedBox(
        width: box.maxWidth,
        height: height,
        child: CustomPaint(
          painter: _SectionPainter(
            section: section,
            thickness: t,
            end: end,
          ),
        ),
      );
    },
  );
}

class _SectionPainter extends CustomPainter {
  _SectionPainter({
    required this.section,
    required this.thickness,
    required this.end,
  });

  final CncSection section;
  final double thickness;
  final double end;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / end;
    final sy = size.height / thickness;
    final last = min(section.depths.length - 1, (end / section.step).ceil());
    final path = Path()..moveTo(0, size.height);
    for (var k = 0; k <= last; k++) {
      path.lineTo(
        min(k * section.step, end) * sx,
        section.depths[k].clamp(0.0, thickness) * sy,
      );
    }
    path
      ..lineTo(size.width, section.depths[last].clamp(0.0, thickness) * sy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = AppColors.sectionBoard)
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.sectionEdge
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_SectionPainter old) =>
      !identical(old.section, section) ||
      old.thickness != thickness ||
      old.end != end;
}
