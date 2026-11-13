import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// One day's money as a waterfall: what came in, what went out of it, and
/// what is left — the figure «Закрыть день» is checked against (owner,
/// 14.11.2026). A bar chart of one day would be one bar; this says how the
/// day got to its balance.
class DayWaterfall extends StatelessWidget {
  const DayWaterfall({
    required this.incoming,
    required this.outgoing,
    required this.labels,
    required this.semanticLabel,
    super.key,
  });

  final double incoming;
  final double outgoing;

  /// Under the three bars: «Пришло», «Ушло», «Остаток».
  final (String, String, String) labels;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final (a, b, c) = labels;
    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, box) => CustomPaint(
              size: Size(box.maxWidth, AppChart.height),
              painter: _WaterfallPainter(
                incoming: incoming,
                outgoing: outgoing,
                up: status.success,
                down: status.danger,
                total: theme.colorScheme.primary,
                line: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final l in [a, b, c])
                Expanded(
                  child: Text(l, textAlign: TextAlign.center, style: style),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter({
    required this.incoming,
    required this.outgoing,
    required this.up,
    required this.down,
    required this.total,
    required this.line,
  });

  final double incoming;
  final double outgoing;
  final Color up;
  final Color down;
  final Color total;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final left = incoming - outgoing;
    // The highest point the bars reach and the lowest: a day that paid out
    // more than it took in ends below the line.
    final high = math.max(incoming, 0);
    final low = math.min(left, 0);
    final range = high - low;
    final scale = range == 0 ? 0.0 : size.height / range;
    double y(double v) =>
        range == 0 ? size.height : size.height - (v - low) * scale;
    final slot = size.width / 3;
    final width = math.min(slot * AppChart.barShare, AppChart.maxBar * 2);
    const radius = Radius.circular(AppRadius.xs);

    void bar(int i, double from, double to, Color color) {
      if (from == to) return;
      final x = slot * i + (slot - width) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x,
            y(math.max(from, to)),
            x + width,
            y(math.min(from, to)),
          ),
          radius,
        ),
        Paint()..color = color,
      );
    }

    bar(0, 0, incoming, up);
    bar(1, incoming, left, down);
    bar(2, 0, left, total);
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = line
        ..strokeWidth = AppStroke.hairline,
    );
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) =>
      old.incoming != incoming ||
      old.outgoing != outgoing ||
      old.up != up ||
      old.down != down ||
      old.total != total ||
      old.line != line;
}
