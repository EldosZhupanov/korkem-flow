import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';

/// One sheet as it lies on the saw's carriage (owner, 28.11.2026): its
/// height going away from the sawyer, drawn upward — as the settings write
/// it, so 2800 × 2070 stands and 2070 × 2800 lies; the fence on its side;
/// each part with its number, its band as a line on the banded side — thick
/// for 2 mm, dashed for a thin one; the offcuts that go on the shelf, and the
/// waste. The parts of the cut being made are lit.
class SawSheetMap extends StatelessWidget {
  const SawSheetMap({
    required this.sheet,
    required this.heightMm,
    required this.widthMm,
    required this.trimMm,
    required this.fence,
    this.lit = const {},
    this.maxHeight = 520,
    super.key,
  });

  final SawPlanSheet sheet;
  final double heightMm;
  final double widthMm;
  final double trimMm;
  final FenceSide fence;

  /// The pieces of the cut being made, as (n, k).
  final Set<({int n, int k})> lit;
  final double maxHeight;

  /// Room for the fence beside the sheet and the sizes around it.
  static const double side = AppSpacing.xxl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = context.statusColors;
    return LayoutBuilder(
      builder: (context, box) {
        final room = math.max(0, box.maxWidth - 2 * side).toDouble();
        final scale = heightMm > 0 && widthMm > 0
            ? math.min(room / widthMm, maxHeight / heightMm)
            : 0.0;
        final size = Size(
          box.maxWidth,
          heightMm * scale + side,
        );
        return CustomPaint(
          size: size,
          painter: _SheetPainter(
            sheet: sheet,
            heightMm: heightMm,
            widthMm: widthMm,
            trimMm: trimMm,
            fence: fence,
            lit: lit,
            scale: scale,
            part: scheme.primaryContainer,
            partInk: scheme.onPrimaryContainer,
            litPart: status.warning.withValues(alpha: AppTint.warningBand),
            litEdge: status.warning,
            offcut: status.success.withValues(alpha: AppTint.surface),
            offcutEdge: status.success,
            waste: scheme.surfaceContainerHighest,
            outline: scheme.outline,
            band: scheme.tertiary,
            fenceColour: scheme.onSurfaceVariant,
            numberStyle: (theme.textTheme.labelLarge ?? const TextStyle())
                .copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
            sizeStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({
    required this.sheet,
    required this.heightMm,
    required this.widthMm,
    required this.trimMm,
    required this.fence,
    required this.lit,
    required this.scale,
    required this.part,
    required this.partInk,
    required this.litPart,
    required this.litEdge,
    required this.offcut,
    required this.offcutEdge,
    required this.waste,
    required this.outline,
    required this.band,
    required this.fenceColour,
    required this.numberStyle,
    required this.sizeStyle,
  });

  final SawPlanSheet sheet;
  final double heightMm;
  final double widthMm;
  final double trimMm;
  final FenceSide fence;
  final Set<({int n, int k})> lit;
  final double scale;
  final Color part;
  final Color partInk;
  final Color litPart;
  final Color litEdge;
  final Color offcut;
  final Color offcutEdge;
  final Color waste;
  final Color outline;
  final Color band;
  final Color fenceColour;
  final TextStyle numberStyle;
  final TextStyle sizeStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (scale <= 0) return;
    final left = (size.width - widthMm * scale) / 2;
    const top = 0.0;
    final usedW = widthMm - 2 * trimMm;

    // x across from the fence; drawn mirrored when the fence is on the right.
    Rect rect(double x, double y, double w, double h) {
      final across = fence == FenceSide.left ? x : usedW - x - w;
      return Rect.fromLTWH(
        left + (trimMm + across) * scale,
        top + (trimMm + y) * scale,
        w * scale,
        h * scale,
      );
    }

    final whole = Rect.fromLTWH(left, top, widthMm * scale, heightMm * scale);
    _dashed(canvas, whole, Paint()..color = outline);

    for (final r in sheet.waste) {
      canvas.drawRect(rect(r.x, r.y, r.width, r.height), Paint()..color = waste);
    }
    for (final r in sheet.offcuts) {
      final box = rect(r.x, r.y, r.width, r.height);
      canvas
        ..drawRect(box, Paint()..color = offcut)
        ..drawRect(
          box,
          Paint()
            ..color = offcutEdge
            ..style = PaintingStyle.stroke,
        );
    }
    for (final p in sheet.parts) {
      final on = lit.contains((n: p.n, k: p.k));
      final box = rect(p.x, p.y, p.width, p.height);
      canvas
        ..drawRect(box, Paint()..color = on ? litPart : part)
        ..drawRect(
          box,
          Paint()
            ..color = on ? litEdge : outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 2 : 1,
        );
      _bands(canvas, box, p.edges);
      _text(canvas, '${p.n}', box.center, numberStyle, box);
    }

    // The fence, beside the sheet on its side.
    final barX = fence == FenceSide.left
        ? left - AppSpacing.sm - AppSpacing.xs
        : left + widthMm * scale + AppSpacing.sm;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, top, AppSpacing.xs, heightMm * scale),
        const Radius.circular(AppRadius.xs),
      ),
      Paint()..color = fenceColour,
    );
    // Its sizes: the height beside, the width under.
    _text(
      canvas,
      _mm(heightMm),
      Offset(
        fence == FenceSide.left
            ? left + widthMm * scale + SawSheetMap.side / 2
            : left - SawSheetMap.side / 2,
        top + heightMm * scale / 2,
      ),
      sizeStyle,
      null,
    );
    _text(
      canvas,
      _mm(widthMm),
      Offset(left + widthMm * scale / 2, top + heightMm * scale + AppSpacing.md),
      sizeStyle,
      null,
    );
  }

  /// A band as a line inside the banded side: thick for a thick band, a dash
  /// for a thin one.
  void _bands(Canvas canvas, Rect box, List<double> edges) {
    final inset = AppSpacing.xxs;
    final sides = [
      (Offset(box.left + inset, box.top + inset), Offset(box.right - inset, box.top + inset)),
      (Offset(box.left + inset, box.bottom - inset), Offset(box.right - inset, box.bottom - inset)),
      (Offset(box.left + inset, box.top + inset), Offset(box.left + inset, box.bottom - inset)),
      (Offset(box.right - inset, box.top + inset), Offset(box.right - inset, box.bottom - inset)),
    ];
    for (final (i, (a, b)) in sides.indexed) {
      final e = i < edges.length ? edges[i] : 0;
      if (e <= 0) continue;
      final paint = Paint()
        ..color = band
        ..strokeWidth = e >= 1 ? AppSpacing.xs : 1;
      if (e >= 1) {
        canvas.drawLine(a, b, paint);
      } else {
        _dashLine(canvas, a, b, paint);
      }
    }
  }

  void _dashed(Canvas canvas, Rect r, Paint paint) {
    _dashLine(canvas, r.topLeft, r.topRight, paint);
    _dashLine(canvas, r.bottomLeft, r.bottomRight, paint);
    _dashLine(canvas, r.topLeft, r.bottomLeft, paint);
    _dashLine(canvas, r.topRight, r.bottomRight, paint);
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = AppSpacing.xs;
    final length = (b - a).distance;
    if (length == 0) return;
    final step = (b - a) / length;
    for (var d = 0.0; d < length; d += dash * 2) {
      canvas.drawLine(a + step * d, a + step * math.min(d + dash, length), paint);
    }
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style, Rect? within) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    if (within != null &&
        (painter.width > within.width - AppSpacing.xs ||
            painter.height > within.height - AppSpacing.xs)) {
      return;
    }
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  static String _mm(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  bool shouldRepaint(_SheetPainter old) =>
      old.sheet != sheet ||
      old.lit != lit ||
      old.scale != scale ||
      old.fence != fence ||
      old.part != part;
}
