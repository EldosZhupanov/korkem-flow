import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';

/// One press load drawn to scale: the table, and each facade with its order
/// line number large enough to read at the press. A textured film's parts
/// carry an arrow — the way the pattern runs — and a warning colour.
class PressMap extends StatelessWidget {
  const PressMap({
    required this.load,
    required this.widthMm,
    required this.textured,
    super.key,
  });

  final PressLoad load;
  final double widthMm;
  final bool textured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = context.statusColors.warning;
    final ratio = widthMm > 0 && load.lengthMm > 0
        ? load.lengthMm / widthMm
        : 2.5;
    return AspectRatio(
      aspectRatio: ratio,
      child: CustomPaint(
        painter: _PressPainter(
          load: load,
          widthMm: widthMm,
          textured: textured,
          table: scheme.surfaceContainerHighest,
          edge: scheme.outline,
          part: textured
              ? warning.withValues(alpha: AppTint.warningBand)
              : scheme.primaryContainer,
          partEdge: textured ? warning : scheme.primary,
          ink: scheme.onSurface,
          numberStyle: (theme.textTheme.headlineSmall ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
          sizeStyle: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PressPainter extends CustomPainter {
  _PressPainter({
    required this.load,
    required this.widthMm,
    required this.textured,
    required this.table,
    required this.edge,
    required this.part,
    required this.partEdge,
    required this.ink,
    required this.numberStyle,
    required this.sizeStyle,
  });

  final PressLoad load;
  final double widthMm;
  final bool textured;
  final Color table;
  final Color edge;
  final Color part;
  final Color partEdge;
  final Color ink;
  final TextStyle numberStyle;
  final TextStyle sizeStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (load.lengthMm <= 0) return;
    final scale = size.width / load.lengthMm;
    final tableRect = Offset.zero & size;
    canvas
      ..drawRect(tableRect, Paint()..color = table)
      ..drawRect(
        tableRect,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppStroke.hairline,
      );
    for (final p in load.placed) {
      final rect = Rect.fromLTWH(
        p.x * scale,
        p.y * scale,
        p.width * scale,
        p.height * scale,
      );
      canvas
        ..drawRect(rect, Paint()..color = part)
        ..drawRect(
          rect,
          Paint()
            ..color = partEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppStroke.hairline * 1.5,
        );
      final side = math.min(rect.width, rect.height);
      final fontSize = (side * 0.42).clamp(10.0, 40.0);
      _text(
        canvas,
        '${p.pos}',
        numberStyle.copyWith(fontSize: fontSize),
        rect.center,
        rect.width,
      );
      if (side > 28) {
        final dims =
            '${(p.rotated ? p.height : p.width).round()}×'
            '${(p.rotated ? p.width : p.height).round()}';
        _text(
          canvas,
          dims,
          sizeStyle,
          Offset(rect.center.dx, rect.bottom - AppSpacing.sm),
          rect.width,
        );
      }
      if (textured) _arrow(canvas, rect);
    }
  }

  /// Up the part: the way the pattern of a textured film runs.
  void _arrow(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = partEdge
      ..strokeWidth = AppStroke.hairline * 2
      ..style = PaintingStyle.stroke;
    final x = rect.left + math.min(rect.width * 0.18, AppSpacing.lg);
    final top = rect.top + rect.height * 0.2;
    final bottom = rect.bottom - rect.height * 0.2;
    final head = math.min(rect.width, rect.height) * 0.12;
    canvas
      ..drawLine(Offset(x, bottom), Offset(x, top), paint)
      ..drawLine(Offset(x, top), Offset(x - head, top + head), paint)
      ..drawLine(Offset(x, top), Offset(x + head, top + head), paint);
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset centre,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(0, maxWidth));
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PressPainter old) =>
      old.load != load || old.textured != textured || old.part != part;
}
