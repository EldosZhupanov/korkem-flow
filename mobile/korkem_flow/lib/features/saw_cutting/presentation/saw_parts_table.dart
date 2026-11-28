import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One row being typed: its fields and where the cursor goes next.
class SawPartRow {
  SawPartRow([SawPart? part])
    : height = TextEditingController(text: _text(part?.height)),
      width = TextEditingController(text: _text(part?.width)),
      qty = TextEditingController(text: '${part?.qty ?? 1}'),
      name = TextEditingController(text: part?.name ?? ''),
      edges = [
        ...(part?.edges ?? const <double>[0, 0, 0, 0]),
      ],
      rotate = part?.rotate ?? true,
      order = part?.order;

  final TextEditingController height;
  final TextEditingController width;
  final TextEditingController qty;
  final TextEditingController name;
  final FocusNode heightFocus = FocusNode();
  final FocusNode widthFocus = FocusNode();
  final FocusNode qtyFocus = FocusNode();
  final FocusNode nameFocus = FocusNode();
  List<double> edges;
  bool rotate;
  final String? order;

  static String _text(double? v) => v == null || v == 0
      ? ''
      : (v == v.roundToDouble()
            ? v.toStringAsFixed(0)
            : '$v'.replaceAll('.', ','));

  static double? _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim());

  bool get empty =>
      height.text.trim().isEmpty &&
      width.text.trim().isEmpty &&
      name.text.trim().isEmpty;

  /// The row as a part; null — its height or width is missing.
  SawPart? get part {
    final h = _number(height);
    final w = _number(width);
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    return SawPart(
      height: h,
      width: w,
      qty: int.tryParse(qty.text.trim()) ?? 1,
      rotate: rotate,
      edges: edges,
      name: name.text.trim(),
      order: order,
    );
  }

  void dispose() {
    for (final c in [height, width, qty, name]) {
      c.dispose();
    }
    for (final f in [heightFocus, widthFocus, qtyFocus, nameFocus]) {
      f.dispose();
    }
  }
}

/// Band metres by thickness — top and bottom run the width, the sides the
/// height — as the server counts them.
Map<double, double> sawEdgeMetres(List<SawPart> parts) {
  final out = <double, double>{};
  for (final p in parts) {
    for (final (i, e) in p.edges.indexed) {
      if (e <= 0) continue;
      final side = i < 2 ? p.width : p.height;
      out[e] = (out[e] ?? 0) + side * p.qty / 1000;
    }
  }
  return out;
}

/// The parts, numbers first (owner, 28.11.2026): № · Высота · Ширина ·
/// Кол-во · Кромка · Поворот · Название. Height → Tab → width → Tab →
/// quantity → Enter opens the next row with the cursor in its height; the
/// name is optional — empty, the part is «Деталь N».
class SawPartsTable extends StatelessWidget {
  const SawPartsTable({
    required this.rows,
    required this.enabled,
    required this.onChanged,
    required this.onAddRow,
    required this.onRemove,
    super.key,
  });

  final List<SawPartRow> rows;
  final bool enabled;
  final VoidCallback onChanged;

  /// A new row after [after]; the caller focuses it.
  final void Function(int after) onAddRow;
  final void Function(int index) onRemove;

  /// The table's width before it scrolls sideways on a narrow screen.
  static const double minWidth = 720;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final head = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth < minWidth ? minWidth : box.maxWidth;
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line(
                [
                  Text(l10n.sawColNo, style: head),
                  Text(l10n.sawColHeight, style: head),
                  Text(l10n.sawColWidth, style: head),
                  Text(l10n.sawColQty, style: head),
                  Text(l10n.sawColEdge, style: head),
                  Text(l10n.sawColRotate, style: head),
                  Text(l10n.sawColName, style: head),
                  const SizedBox.shrink(),
                ],
              ),
              const Divider(height: 1),
              for (final (i, row) in rows.indexed) _row(context, l10n, i, row),
            ],
          ),
        );
        return box.maxWidth < minWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : table;
      },
    );
  }

  static const _flex = [3, 6, 6, 4, 5, 4, 12, 3];

  Widget _line(List<Widget> cells) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            flex: _flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: c,
            ),
          ),
      ],
    ),
  );

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    int i,
    SawPartRow row,
  ) {
    Widget number(
      String key,
      TextEditingController c,
      FocusNode focus, {
      required void Function() next,
      bool whole = false,
    }) => TextField(
      key: ValueKey('$key:$i'),
      controller: c,
      focusNode: focus,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.numberWithOptions(decimal: !whole),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(whole ? '[0-9]' : '[0-9.,]')),
      ],
      decoration: const InputDecoration(isDense: true),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => next(),
    );

    return _line([
      Text(
        '${i + 1}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      number(
        'sawH',
        row.height,
        row.heightFocus,
        next: row.widthFocus.requestFocus,
      ),
      number(
        'sawW',
        row.width,
        row.widthFocus,
        next: row.qtyFocus.requestFocus,
      ),
      number(
        'sawQ',
        row.qty,
        row.qtyFocus,
        whole: true,
        next: () => onAddRow(i),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SawEdgeCell(
          key: ValueKey('sawEdge:$i'),
          edges: row.edges,
          enabled: enabled,
          onChanged: (edges) {
            row.edges = edges;
            onChanged();
          },
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Checkbox(
          key: ValueKey('sawRotate:$i'),
          value: row.rotate,
          onChanged: enabled
              ? (v) {
                  row.rotate = v ?? true;
                  onChanged();
                }
              : null,
        ),
      ),
      TextField(
        key: ValueKey('sawName:$i'),
        controller: row.name,
        focusNode: row.nameFocus,
        enabled: enabled,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.sawPartDefault(i + 1),
        ),
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onAddRow(i),
      ),
      if (enabled)
        IconButton(
          key: ValueKey('sawRemove:$i'),
          tooltip: l10n.actionCancel,
          icon: const Icon(AppIcons.delete),
          onPressed: () => onRemove(i),
        )
      else
        const SizedBox.shrink(),
    ]);
  }
}

/// The part drawn small; a tap on a side changes its band: none → 0,4 → 2 mm.
class SawEdgeCell extends StatelessWidget {
  const SawEdgeCell({
    required this.edges,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<double> edges;
  final ValueChanged<List<double>> onChanged;
  final bool enabled;

  static const Size size = Size(
    AppSpacing.xxxl + AppSpacing.sm,
    AppSpacing.xxxl - AppSpacing.md,
  );

  static double next(double e) => e <= 0 ? 0.4 : (e < 1 ? 2 : 0);

  /// The side a tap at [at] is nearest: top, bottom, left, right.
  static int sideAt(Offset at) {
    final d = [
      at.dy,
      size.height - at.dy,
      at.dx,
      size.width - at.dx,
    ];
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (d[i] < d[best]) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapUp: enabled
            ? (e) {
                final side = sideAt(e.localPosition);
                onChanged([
                  for (final (i, v) in edges.indexed) i == side ? next(v) : v,
                ]);
              }
            : null,
        child: CustomPaint(
          size: size,
          painter: _EdgePainter(
            edges: edges,
            band: scheme.tertiary,
            plain: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.edges, required this.band, required this.plain});

  final List<double> edges;
  final Color band;
  final Color plain;

  @override
  void paint(Canvas canvas, Size size) {
    const i = AppSpacing.xs;
    final sides = [
      (const Offset(i, i), Offset(size.width - i, i)),
      (Offset(i, size.height - i), Offset(size.width - i, size.height - i)),
      (const Offset(i, i), Offset(i, size.height - i)),
      (Offset(size.width - i, i), Offset(size.width - i, size.height - i)),
    ];
    for (final (k, (a, b)) in sides.indexed) {
      final e = k < edges.length ? edges[k] : 0;
      final paint = Paint()
        ..color = e > 0 ? band : plain
        ..strokeWidth = e >= 1 ? AppSpacing.xs : 1;
      if (e > 0 && e < 1) {
        const dash = AppSpacing.xs;
        final length = (b - a).distance;
        final step = (b - a) / length;
        for (var d = 0.0; d < length; d += dash * 2) {
          canvas.drawLine(
            a + step * d,
            a + step * (d + dash > length ? length : d + dash),
            paint,
          );
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges;
}
