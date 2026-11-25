import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// One slot of a [FlowBars] chart: what came in and what went out.
@immutable
class FlowBar {
  const FlowBar({required this.label, this.up = 0, this.down = 0});

  /// Under the slot: «Пн», «14».
  final String label;

  /// Drawn above the line, in the success colour.
  final double up;

  /// Drawn below the line, in the danger colour. Given as a positive amount.
  final double down;
}

/// Money in above the line and money out below it, slot by slot — a day
/// each, as a rule (owner, 14.11.2026: «график, который поднимается и
/// фильтруется»).
///
/// Tapping a slot picks it and tapping it again lets it go: [onSelect] is
/// told which, so the list under the chart can follow. Painted by hand, as
/// the press map is, rather than through a chart package: three shapes do
/// not justify a dependency, and every colour here is the theme's own.
class FlowBars extends StatelessWidget {
  const FlowBars({
    required this.bars,
    required this.semanticLabel,
    this.selected,
    this.onSelect,
    super.key,
  });

  final List<FlowBar> bars;

  /// What the chart shows, for a screen reader: it cannot see the bars.
  final String semanticLabel;

  /// The picked slot, or null for none.
  final int? selected;
  final ValueChanged<int?>? onSelect;

  /// Every label under a short run; under a month, one in [_labelStep]
  /// of them, or they run into each other.
  static const int _allLabels = 10;
  static const int _labelStep = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final n = bars.length;
    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: n == 0 || onSelect == null
                  ? null
                  : (d) {
                      final at = (d.localPosition.dx / box.maxWidth * n)
                          .floor();
                      final i = math.min(math.max(at, 0), n - 1);
                      onSelect!(i == selected ? null : i);
                    },
              child: CustomPaint(
                size: Size(box.maxWidth, AppChart.height),
                painter: _FlowPainter(
                  bars: bars,
                  selected: selected,
                  up: status.success,
                  down: status.danger,
                  line: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // A month's bar is narrower than «26» on a phone: each label is
          // centred under its bar and may spill into its empty neighbours,
          // rather than be cut to «2» (design review, 25.11.2026).
          LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / n;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // The line's height; the labels hang on it.
                  SizedBox(
                    width: double.infinity,
                    child: Text(' ', style: labelStyle),
                  ),
                  for (var i = 0; i < n; i++)
                    if (n <= _allLabels || i % _labelStep == 0 || i == n - 1)
                      Positioned(
                        left: slot * i + slot / 2,
                        top: 0,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: Text(
                            bars[i].label,
                            maxLines: 1,
                            softWrap: false,
                            style: i == selected
                                ? labelStyle?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  )
                                : labelStyle,
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.bars,
    required this.selected,
    required this.up,
    required this.down,
    required this.line,
  });

  final List<FlowBar> bars;
  final int? selected;
  final Color up;
  final Color down;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final top = bars.map((b) => b.up).fold<double>(0, math.max);
    final bottom = bars.map((b) => b.down).fold<double>(0, math.max);
    final range = top + bottom;
    // Nothing moved: the line alone, in the middle.
    final zero = range == 0 ? size.height / 2 : size.height * top / range;
    final scale = range == 0 ? 0.0 : size.height / range;
    final slot = size.width / bars.length;
    final width = math.min(slot * AppChart.barShare, AppChart.maxBar);
    const radius = Radius.circular(AppRadius.xs);
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final faded = selected != null && selected != i;
      final left = slot * i + (slot - width) / 2;
      if (b.up > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, zero - b.up * scale, width, b.up * scale),
            topLeft: radius,
            topRight: radius,
          ),
          Paint()
            ..color = faded ? up.withValues(alpha: AppTint.chartFaded) : up,
        );
      }
      if (b.down > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, zero, width, b.down * scale),
            bottomLeft: radius,
            bottomRight: radius,
          ),
          Paint()
            ..color = faded ? down.withValues(alpha: AppTint.chartFaded) : down,
        );
      }
    }
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = line
        ..strokeWidth = AppStroke.hairline,
    );
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.bars != bars ||
      old.selected != selected ||
      old.up != up ||
      old.down != down ||
      old.line != line;
}
