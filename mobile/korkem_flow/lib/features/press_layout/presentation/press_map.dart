import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One press load drawn to scale: the table, and each facade with its order
/// line number large enough to read at the press. Each position has its own
/// colour, the same on every load (owner, 13.11.2026), and a position can be
/// lit up: the rest fade.
///
/// Owner, 26.11.2026, «чтобы вакуумщики при раскладке знали и не тупили»:
/// - every load is drawn on the whole table, at one scale — a short section
///   no longer swells to the width of the screen; the table past it is
///   dashed, with how much of it is free;
/// - a ruler along the top and the side, 0–500–1000 mm;
/// - each part's sizes as it lies: its length along the bottom edge, its
///   width up the side edge;
/// - the margin, when the press keeps one, as a red dashed line;
/// - a textured film's parts carry an arrow along the table — the way the
///   roll, and so the pattern, runs.
class PressMap extends StatelessWidget {
  const PressMap({
    required this.load,
    required this.widthMm,
    required this.textured,
    this.tableMm,
    this.marginMm = 0,
    this.highlight,
    this.onHover,
    this.onTap,
    super.key,
  });

  final PressLoad load;
  final double widthMm;
  final bool textured;

  /// The whole table's length — every load drawn on it; null — the load's
  /// own section.
  final double? tableMm;

  /// The press's margin at the edge; 0 — none drawn.
  final double marginMm;

  /// The position lit up; null — all alike.
  final int? highlight;

  /// The position under the pointer, or null when it left the parts.
  final ValueChanged<int?>? onHover;
  final ValueChanged<int?>? onTap;

  /// Room for the ruler: its figures above the table and left of it.
  static const double rulerTop = AppSpacing.lg;
  static const double rulerLeft = AppSpacing.xxl;

  /// The colour of a position, the same on every load and in the legend.
  static Color colourOf(int pos) => AppColors.filmGroup(pos - 1);

  double get _length =>
      math.max(tableMm ?? 0, load.lengthMm).toDouble();

  int? _at(Offset at, double scale) {
    if (scale <= 0) return null;
    final x = (at.dx - rulerLeft) / scale;
    final y = (at.dy - rulerTop) / scale;
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
    final length = _length;
    return LayoutBuilder(
      builder: (context, box) {
        final inner = math.max(0, box.maxWidth - rulerLeft).toDouble();
        final scale = length > 0 && widthMm > 0 ? inner / length : 0.0;
        final height = rulerTop + (scale > 0 ? widthMm * scale : inner / 2.5);
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
              size: Size(box.maxWidth, height),
              painter: _PressPainter(
                load: load,
                lengthMm: length,
                widthMm: widthMm,
                marginMm: marginMm,
                textured: textured,
                highlight: highlight,
                table: scheme.surfaceContainerHighest,
                edge: scheme.outline,
                ink: scheme.onSurface,
                muted: scheme.onSurfaceVariant,
                margin: context.statusColors.danger,
                numberStyle:
                    (theme.textTheme.headlineSmall ?? const TextStyle())
                        .copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                sizeStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                    .copyWith(color: scheme.onSurface),
                rulerStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                    .copyWith(color: scheme.onSurfaceVariant),
                freeLabel: (m) => AppLocalizations.of(context).pressFree(m),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PressPainter extends CustomPainter {
  _PressPainter({
    required this.load,
    required this.lengthMm,
    required this.widthMm,
    required this.marginMm,
    required this.textured,
    required this.highlight,
    required this.table,
    required this.edge,
    required this.ink,
    required this.muted,
    required this.margin,
    required this.numberStyle,
    required this.sizeStyle,
    required this.rulerStyle,
    required this.freeLabel,
  });

  final PressLoad load;
  final double lengthMm;
  final double widthMm;
  final double marginMm;
  final bool textured;
  final int? highlight;
  final Color table;
  final Color edge;
  final Color ink;
  final Color muted;
  final Color margin;
  final TextStyle numberStyle;
  final TextStyle sizeStyle;
  final TextStyle rulerStyle;
  final String Function(String metres) freeLabel;

  /// One ruler mark every this many millimetres.
  static const double _step = 500;

  @override
  void paint(Canvas canvas, Size size) {
    if (lengthMm <= 0 || widthMm <= 0) return;
    const left = PressMap.rulerLeft;
    const top = PressMap.rulerTop;
    final scale = (size.width - left) / lengthMm;
    final w = lengthMm * scale;
    final h = widthMm * scale;
    final tableRect = Rect.fromLTWH(left, top, w, h);
    final line = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hairline;
    canvas
      ..drawRect(tableRect, Paint()..color = table)
      ..drawRect(tableRect, line);
    _ruler(canvas, scale);
    // The table past this load's section: dashed, with what is free.
    final used = load.lengthMm * scale;
    if (load.lengthMm > 0 && load.lengthMm < lengthMm - 1) {
      final free = Rect.fromLTWH(left + used, top, w - used, h);
      canvas.drawRect(
        free,
        Paint()..color = edge.withValues(alpha: AppTint.surface),
      );
      _dashed(canvas, free, edge);
      final metres = ((lengthMm - load.lengthMm) / 1000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      _text(canvas, freeLabel(metres), rulerStyle, free.center, free.width);
    }
    if (marginMm > 0) {
      final m = marginMm * scale;
      final end = load.lengthMm > 0 ? used : w;
      _dashed(
        canvas,
        Rect.fromLTWH(left + m, top + m, end - 2 * m, h - 2 * m),
        margin,
      );
    }
    for (final p in load.placed) {
      final rect = Rect.fromLTWH(
        left + p.x * scale,
        top + p.y * scale,
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
      // Its sizes as it lies: the length along the bottom, the width up
      // the side (owner, 26.11.2026).
      if (rect.width > AppSpacing.xl && rect.height > AppSpacing.lg) {
        _text(
          canvas,
          '${p.width.round()}',
          sizeStyle,
          Offset(rect.center.dx, rect.bottom - AppSpacing.sm),
          rect.width,
        );
      }
      if (rect.height > AppSpacing.xl && rect.width > AppSpacing.xl) {
        canvas
          ..save()
          ..translate(rect.right - AppSpacing.sm, rect.center.dy)
          ..rotate(-math.pi / 2);
        _text(canvas, '${p.height.round()}', sizeStyle, Offset.zero, rect.height);
        canvas.restore();
      }
      // A plain film's part turned a quarter from the order's way.
      if (p.rotated && !textured && side > 20) {
        _text(
          canvas,
          '↻',
          sizeStyle,
          rect.topRight + const Offset(-AppSpacing.lg, AppSpacing.sm),
          rect.width,
        );
      }
      if (textured) _arrow(canvas, rect, colour);
    }
  }

  void _ruler(Canvas canvas, double scale) {
    const left = PressMap.rulerLeft;
    const top = PressMap.rulerTop;
    final tick = Paint()
      ..color = muted
      ..strokeWidth = AppStroke.hairline;
    for (var mm = 0.0; mm <= lengthMm + 0.5; mm += _step) {
      final x = left + mm * scale;
      canvas.drawLine(Offset(x, top - AppSpacing.xs), Offset(x, top), tick);
      _text(
        canvas,
        '${mm.round()}',
        rulerStyle,
        Offset(x, top - AppSpacing.sm - AppSpacing.xxs),
        _step * scale,
      );
    }
    for (var mm = 0.0; mm <= widthMm + 0.5; mm += _step) {
      final y = top + mm * scale;
      canvas.drawLine(Offset(left - AppSpacing.xs, y), Offset(left, y), tick);
      final painter = TextPainter(
        text: TextSpan(text: '${mm.round()}', style: rulerStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          left - AppSpacing.sm - painter.width,
          y - painter.height / 2,
        ),
      );
    }
  }

  void _dashed(Canvas canvas, Rect rect, Color colour) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = AppStroke.hairline;
    const dash = AppSpacing.xs;
    void run(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length <= 0) return;
      final step = (b - a) / length;
      for (var d = 0.0; d < length; d += dash * 2) {
        canvas.drawLine(
          a + step * d,
          a + step * math.min(d + dash, length),
          paint,
        );
      }
    }

    run(rect.topLeft, rect.topRight);
    run(rect.topRight, rect.bottomRight);
    run(rect.bottomRight, rect.bottomLeft);
    run(rect.bottomLeft, rect.topLeft);
  }

  /// Along the table: the way the roll, and a textured film's pattern, runs.
  void _arrow(Canvas canvas, Rect rect, Color colour) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = AppStroke.hairline * 2
      ..style = PaintingStyle.stroke;
    final y = rect.top + math.min(rect.height * 0.2, AppSpacing.md);
    final from = rect.left + math.min(rect.width * 0.1, AppSpacing.md);
    final to = rect.left + math.min(rect.width * 0.6, rect.width - AppSpacing.md);
    if (to <= from) return;
    final head = math.min(rect.width, rect.height) * 0.1;
    canvas
      ..drawLine(Offset(from, y), Offset(to, y), paint)
      ..drawLine(Offset(to, y), Offset(to - head, y - head), paint)
      ..drawLine(Offset(to, y), Offset(to - head, y + head), paint);
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
      old.lengthMm != lengthMm ||
      old.marginMm != marginMm ||
      old.textured != textured ||
      old.highlight != highlight ||
      old.ink != ink;
}
