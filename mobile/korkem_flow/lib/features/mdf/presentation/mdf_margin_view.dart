import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_margin.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A margin under this share of the total is thin.
const double mdfThinMargin = 0.2;

/// The colour a margin reads in: a loss is red, a thin one amber.
Color mdfMarginColor(BuildContext context, double margin, double? share) {
  final status = context.statusColors;
  if (margin < 0) return status.danger;
  if (share != null && share < mdfThinMargin) return status.warning;
  return status.success;
}

/// «42 %», or nothing for an order with no price.
String mdfShare(double? share) =>
    share == null ? '' : ' · ${(share * 100).round()}%';

/// The order card's margin (owner, 14.11.2026): what the order earned over
/// material and work, as one bar; tap it for what the material was.
///
/// Nothing is drawn while it loads or when the server will not say — a card
/// that waits for its margin would wait for the less important thing.
class MdfMarginView extends ConsumerStatefulWidget {
  const MdfMarginView({required this.order, super.key});

  final String order;

  @override
  ConsumerState<MdfMarginView> createState() => _MdfMarginViewState();
}

class _MdfMarginViewState extends ConsumerState<MdfMarginView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(mdfMarginProvider(widget.order)).value;
    if (m == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final colour = mdfMarginColor(context, m.margin, m.share);
    final small = theme.textTheme.bodySmall;
    return InkWell(
      key: const ValueKey('mdfMargin'),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.mdfMarginTitle}: ${money.format(m.margin)}'
                    '${mdfShare(m.share)}',
                    key: const ValueKey('mdfMarginValue'),
                    style: theme.textTheme.titleSmall?.copyWith(color: colour),
                  ),
                ),
                Icon(_open ? AppIcons.collapse : AppIcons.expand),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            _SplitBar(margin: m, colour: colour),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${l10n.mdfMarginMaterial} ${money.format(m.material)} · '
              '${l10n.mdfMarginWork} ${money.format(m.work)}',
              style: small,
            ),
            if (m.estimate)
              Text(
                l10n.mdfMarginEstimate,
                key: const ValueKey('mdfMarginEstimate'),
                style: small?.copyWith(color: context.statusColors.warning),
              ),
            if (_open) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final r in m.materials)
                Text(
                  '${r.title} — ${r.qty.toStringAsFixed(2)} ${r.unit} — '
                  '${money.format(r.cost)}',
                  style: small,
                ),
              if (m.missing.isNotEmpty)
                Text(
                  l10n.mdfMarginMissing(m.missing.join(', ')),
                  style: small?.copyWith(color: context.statusColors.danger),
                ),
              Text(
                l10n.mdfMarginNotCounted,
                key: const ValueKey('mdfMarginNotCounted'),
                style: small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The total split into material, work and what is left. A loss draws no
/// margin segment: the bar then is all cost.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.margin, required this.colour});

  final MdfMargin margin;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      (margin.material, scheme.tertiary),
      (margin.work, scheme.secondary),
      (margin.margin, colour),
    ].where((p) => p.$1 > 0).toList();
    final whole = parts.fold<double>(0, (sum, p) => sum + p.$1);
    if (whole <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: SizedBox(
        height: AppSpacing.sm,
        child: Row(
          children: [
            for (final (value, c) in parts)
              Expanded(
                flex: (value / whole * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: c),
              ),
          ],
        ),
      ),
    );
  }
}
