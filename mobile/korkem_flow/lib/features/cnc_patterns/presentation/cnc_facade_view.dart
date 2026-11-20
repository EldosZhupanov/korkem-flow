import 'dart:math';

import 'package:flutter/material.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';

/// A facade from above with the pattern's cuts, each as wide as it leaves
/// on the face — what the operator will see before the router does.
class CncFacadeView extends StatelessWidget {
  const CncFacadeView({
    required this.width,
    required this.height,
    required this.cuts,
    this.progress = 1,
    super.key,
  });

  /// The facade, mm.
  final double width;
  final double height;
  final List<CncCut> cuts;

  /// How much of the cutter's run is drawn, 0…1 — the simulation (owner,
  /// 20.11.2026, ArtCAM's «Симуляция»); the cutter shown where it stands.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final scale = width <= 0 || height <= 0
            ? 1.0
            : min(box.maxWidth / width, box.maxHeight / height);
        return Center(
          child: SizedBox(
            width: width * scale,
            height: height * scale,
            child: CustomPaint(
              painter: _FacadePainter(
                width: width,
                height: height,
                cuts: cuts,
                progress: progress,
                board: scheme.surfaceContainerHighest,
                edge: scheme.outline,
                cut: scheme.primary,
                cutter: scheme.error,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FacadePainter extends CustomPainter {
  _FacadePainter({
    required this.width,
    required this.height,
    required this.cuts,
    required this.progress,
    required this.board,
    required this.edge,
    required this.cut,
    required this.cutter,
  });

  final double width;
  final double height;
  final List<CncCut> cuts;
  final double progress;
  final Color board;
  final Color edge;
  final Color cut;
  final Color cutter;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / width;
    final face = Offset.zero & size;
    canvas
      ..drawRect(face, Paint()..color = board)
      ..drawRect(
        face,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke,
      )
      ..save()
      ..clipRect(face);
    // Millimetres from the bottom-left corner, as the router counts them.
    Offset at(Offset mm) => Offset(mm.dx * scale, size.height - mm.dy * scale);
    // The run so far: every cut in turn, as far along as [progress] reaches.
    var total = 0.0;
    for (final c in cuts) {
      for (var i = 1; i < c.points.length; i++) {
        total += (c.points[i] - c.points[i - 1]).distance;
      }
    }
    var left = progress >= 1 ? double.infinity : total * max<double>(0, progress);
    Offset? head;
    for (final c in cuts) {
      if (c.points.length < 2 || left <= 0) continue;
      final path = Path()..moveTo(at(c.points.first).dx, at(c.points.first).dy);
      for (var i = 1; i < c.points.length && left > 0; i++) {
        final a = c.points[i - 1];
        final b = c.points[i];
        final len = (b - a).distance;
        final end = len <= left || len == 0 ? b : a + (b - a) * (left / len);
        left -= len;
        final o = at(end);
        path.lineTo(o.dx, o.dy);
        head = o;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = cut
          ..style = PaintingStyle.stroke
          ..strokeWidth = max<double>(1, c.width * scale)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (progress < 1 && head != null) {
      canvas.drawCircle(
        head,
        max<double>(3, 6 * scale),
        Paint()..color = cutter,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacadePainter old) =>
      old.cuts != cuts ||
      old.progress != progress ||
      old.width != width ||
      old.height != height ||
      old.cut != cut ||
      old.board != board;
}
