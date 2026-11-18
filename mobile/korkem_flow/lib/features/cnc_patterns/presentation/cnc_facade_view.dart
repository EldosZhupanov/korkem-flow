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
    super.key,
  });

  /// The facade, mm.
  final double width;
  final double height;
  final List<CncCut> cuts;

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
                board: scheme.surfaceContainerHighest,
                edge: scheme.outline,
                cut: scheme.primary,
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
    required this.board,
    required this.edge,
    required this.cut,
  });

  final double width;
  final double height;
  final List<CncCut> cuts;
  final Color board;
  final Color edge;
  final Color cut;

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
    for (final c in cuts) {
      if (c.points.length < 2) continue;
      final path = Path()..moveTo(at(c.points.first).dx, at(c.points.first).dy);
      for (final p in c.points.skip(1)) {
        final o = at(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = cut
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, c.width * scale)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacadePainter old) =>
      old.cuts != cuts ||
      old.width != width ||
      old.height != height ||
      old.cut != cut ||
      old.board != board;
}
