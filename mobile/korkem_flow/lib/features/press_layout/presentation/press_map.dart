import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';

/// One press load drawn to scale: the table, and each facade with its order
/// line number large enough to read at the press. Each position has its own
/// colour, the same on every load (owner, 13.11.2026), and a position can be
/// lit up: the rest fade. A textured film's parts carry an arrow — the way
/// the pattern runs.
class PressMap extends StatelessWidget {
  const PressMap({
    required this.load,
    required this.widthMm,
    required this.textured,
    this.highlight,
    this.onHover,
    this.onTap,
    super.key,
  });

  final PressLoad load;
  final double widthMm;
  final bool textured;

  /// The position lit up; null — all alike.
  final int? highlight;

  /// The position under the pointer, or null when it left the parts.
  final ValueChanged<int?>? onHover;
  final ValueChanged<int?>? onTap;

  /// The colour of a position, the same on every load and in the legend.
  static Color colourOf(int pos) => AppColors.filmGroup(pos - 1);

  int? _at(Offset at, double scale) {
    if (scale <= 0) return null;
    final x = at.dx / scale;
    final y = at.dy / scale;
    for (final p in load.placed) {
      if (x >= p.x && x <= p.x + p.width && y >= p.y && y <= p.y + p.height) {
        return p.pos;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = widthMm > 0 && load.lengthMm > 0
        ? load.lengthMm / widthMm
        : 2.5;
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = load.lengthMm > 0 ? box.maxWidth / load.lengthMm : 0.0;
          return MouseRegion(
            onHover: onHover == null
                ? null
                : (e) => onHover!(_at(e.localPosition, scale)),
            onExit: onHover == null ? null : (_) => onHover!(null),
            child: GestureDetector(
              onTapUp: onTap == null
                  ? null
                  : (e) => onTap!(_at(e.localPosition, scale)),
              child: CustomPaint(
                size: Size(box.maxWidth, box.maxHeight),
                painter: _PressPainter(
                  load: load,
                  widthMm: widthMm,
                  textured: textured,
                  highlight: highlight,
                  table: scheme.surfaceContainerHighest,
                  edge: scheme.outline,
                  ink: scheme.onSurface,
                  numberStyle:
                      (theme.textTheme.headlineSmall ?? const TextStyle())
                          .copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                  sizeStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                      .copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PressPainter extends CustomPainter {
  _PressPainter({
    required this.load,
    required this.widthMm,
    required this.textured,
    required this.highlight,
    required this.table,
    required this.edge,
    required this.ink,
    required this.numberStyle,
    required this.sizeStyle,
  });

  final PressLoad load;
  final double widthMm;
  final bool textured;
  final int? highlight;
  final Color table;
  final Color edge;
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
      // Its own colour; a position lit up stands out, the rest fade.
      final colour = PressMap.colourOf(p.pos);
      final lit = highlight == null || highlight == p.pos;
      canvas
        ..drawRect(
          rect,
          Paint()
            ..color = colour.withValues(
              alpha: lit ? AppTint.pressPart : AppTint.pressPartFaded,
            ),
        )
        ..drawRect(
          rect,
          Paint()
            ..color = lit ? colour : colour.withValues(alpha: AppTint.surface)
            ..style = PaintingStyle.stroke
            ..strokeWidth = highlight == p.pos
                ? AppStroke.focus * 1.5
                : AppStroke.focus,
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
      // Turned a quarter from the order's way.
      if (p.rotated && side > 20) {
        _text(
          canvas,
          '↻',
          sizeStyle,
          rect.topRight + const Offset(-AppSpacing.sm, AppSpacing.sm),
          rect.width,
        );
      }
      if (textured) _arrow(canvas, rect, colour);
    }
  }

  /// Up the part: the way the pattern of a textured film runs.
  void _arrow(Canvas canvas, Rect rect, Color colour) {
    final paint = Paint()
      ..color = colour
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
      old.load != load ||
      old.textured != textured ||
      old.highlight != highlight ||
      old.ink != ink;
}
