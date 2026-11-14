import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// One figure over a department's list (owner, 14.11.2026: a dashboard on
/// every department): what it counts, the number, a line under it. A tap,
/// where there is one, narrows the list below to what the figure counts.
class FigureTile extends StatelessWidget {
  const FigureTile({
    required this.id,
    required this.title,
    required this.value,
    this.note,
    this.colour,
    this.selected = false,
    this.onTap,
    super.key,
  });

  /// Names the tile for tests and state: `figure:<id>`.
  final String id;
  final String title;
  final String value;
  final String? note;

  /// The number's colour — a status, when the figure is one to act on.
  final Color? colour;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: selected
            ? BorderSide(
                color: theme.colorScheme.primary,
                width: AppStroke.focus,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        key: ValueKey('figure:$id'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                key: ValueKey('figure:$id:value'),
                style: theme.textTheme.titleLarge?.copyWith(color: colour),
                overflow: TextOverflow.ellipsis,
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of [FigureTile]s of equal width; two to a line on a narrow screen.
class FigureRow extends StatelessWidget {
  const FigureRow({required this.tiles, super.key});

  final List<FigureTile> tiles;

  /// Under this width four tiles in a line cannot hold their numbers.
  static const double _narrow = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final perLine = box.maxWidth < _narrow ? 2 : tiles.length;
        final lines = <List<FigureTile>>[
          for (var i = 0; i < tiles.length; i += perLine)
            tiles.sublist(i, (i + perLine).clamp(0, tiles.length)),
        ];
        return Column(
          children: [
            for (final (n, line) in lines.indexed) ...[
              if (n > 0) const SizedBox(height: AppSpacing.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, tile) in line.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: tile),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
