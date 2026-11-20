import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
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

  /// «Указать цену»: a material with none gets one on its card.
  Future<void> _price(String item, String title) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final price = await showDialog<double>(
      context: context,
      builder: (_) => _PriceDialog(title: title),
    );
    if (price == null || price <= 0 || !mounted) return;
    try {
      await ref
          .read(mdfOrderRepositoryProvider)
          .setMaterialPrice(widget.order, item, price);
      ref.invalidate(mdfMarginProvider(widget.order));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(mdfMarginProvider(widget.order)).value;
    if (m == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    // A price missing: not the success colour, whatever the share says
    // (owner, 20.11.2026: «Маржа 98%» with the film at 0 ₸).
    final colour = m.unsure
        ? status.warning
        : mdfMarginColor(context, m.margin, m.share);
    final small = theme.textTheme.bodySmall;
    final muted = small?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final total = m.material + m.work + (m.margin > 0 ? m.margin : 0);
    String pct(double v) =>
        total <= 0 ? '0%' : '${(v / total * 100).round()}%';
    Widget row(
      String title,
      String qty,
      Widget price,
      Widget sum, {
      Key? key,
      TextStyle? style,
    }) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(title, style: style ?? small)),
          Expanded(
            flex: 2,
            child: Text(qty, style: style ?? small, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: price),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: sum),
          ),
        ],
      ),
    );
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
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${l10n.mdfMarginTitle}: '
                        '${m.unsure || m.estimate ? '≈ ' : ''}'
                        '${money.format(m.margin)}${mdfShare(m.share)}',
                        key: const ValueKey('mdfMarginValue'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colour,
                        ),
                      ),
                      if (m.unsure)
                        Text(
                          l10n.mdfMarginUnsure(m.missing.length),
                          key: const ValueKey('mdfMarginUnsure'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: status.warning,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(_open ? AppIcons.collapse : AppIcons.expand),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            _SplitBar(margin: m, colour: colour),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.mdfMarginShares(
                pct(m.material),
                pct(m.work),
                pct(m.margin > 0 ? m.margin : 0),
              ),
              style: muted,
            ),
            if (m.estimate && !_open)
              Text(
                l10n.mdfMarginEstimate,
                key: const ValueKey('mdfMarginEstimate'),
                style: small?.copyWith(color: status.warning),
              ),
            if (_open) ...[
              const SizedBox(height: AppSpacing.xs),
              row(
                l10n.mdfMarginMaterials,
                l10n.mdfMarginQty,
                Text(l10n.mdfMarginPrice, style: muted),
                Text(l10n.mdfMarginSum, style: muted),
                style: theme.textTheme.labelMedium,
              ),
              for (final r in m.materials)
                row(
                  r.title,
                  '${r.qty.toStringAsFixed(2).replaceAll('.', ',')} ${r.unit}',
                  r.price == null
                      ? Text(
                          l10n.mdfMarginNoPrice,
                          style: small?.copyWith(color: status.danger),
                        )
                      : Text(money.format(r.price ?? 0), style: small),
                  r.price == null && r.item != null
                      ? TextButton(
                          key: ValueKey('mdfMarginPrice:${r.item}'),
                          onPressed: () => _price(r.item!, r.title),
                          child: Text(l10n.mdfMarginSetPrice),
                        )
                      : Text(money.format(r.cost), style: small),
                  key: ValueKey('mdfMarginRow:${r.item ?? r.title}'),
                ),
              const Divider(height: AppSpacing.md),
              row(
                l10n.mdfMarginWork,
                '',
                const SizedBox.shrink(),
                m.work > 0
                    ? Text(money.format(m.work), style: small)
                    : TextButton(
                        key: const ValueKey('mdfMarginRates'),
                        onPressed: () => context.push(Routes.pieceWork),
                        child: Text(l10n.mdfMarginRates),
                      ),
                style: theme.textTheme.labelMedium,
              ),
              if (m.work <= 0)
                Text(l10n.mdfMarginNoWork, style: muted),
              const Divider(height: AppSpacing.md),
              row(
                l10n.mdfMarginCost,
                '',
                const SizedBox.shrink(),
                Text(
                  '${m.unsure ? '≈ ' : ''}'
                  '${money.format(m.material + m.work)}',
                  style: theme.textTheme.labelLarge,
                ),
                style: theme.textTheme.labelLarge,
              ),
              row(
                l10n.mdfMarginRevenue,
                '',
                const SizedBox.shrink(),
                Text(money.format(m.revenue), style: small),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (m.estimate) l10n.mdfMarginEstimateShort,
                  l10n.mdfMarginNotCountedShort,
                ].join(' · '),
                key: const ValueKey('mdfMarginNotCounted'),
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Цена: …» — the dialog keeps its own field, so it lives as long as the
/// dialog does, closing animation included.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.title});

  final String title;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfMarginPriceTitle(widget.title)),
      content: TextField(
        key: const ValueKey('mdfMarginPriceField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.mdfMarginPriceLabel,
          helperText: l10n.mdfMarginPriceHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfMarginPriceSave'),
          onPressed: () => Navigator.of(context).pop(
            double.tryParse(
              _controller.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
            ),
          ),
          child: Text(l10n.pcSave),
        ),
      ],
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
