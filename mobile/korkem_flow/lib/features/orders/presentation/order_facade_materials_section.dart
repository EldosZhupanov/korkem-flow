import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// MDF and film a facade order needs, what is held for it and what is short.
///
/// Every figure is the server's: it counts sheets and running metres from the
/// order's square metres with the factory's own norms. The screen only says
/// what came back, and lets the warehouse hold what has since arrived.
class OrderFacadeMaterialsSection extends ConsumerStatefulWidget {
  const OrderFacadeMaterialsSection({required this.salesOrder, super.key});

  final String salesOrder;

  @override
  ConsumerState<OrderFacadeMaterialsSection> createState() =>
      _OrderFacadeMaterialsSectionState();
}

class _OrderFacadeMaterialsSectionState
    extends ConsumerState<OrderFacadeMaterialsSection> {
  bool _busy = false;

  Future<void> _reserve() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(materialStockRepositoryProvider)
          .reserveFacadeMaterials(widget.salesOrder);
      ref
        ..invalidate(facadeMaterialsProvider(widget.salesOrder))
        ..invalidate(stockMaterialsProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEdit = ref.watch(materialListsProvider).value?.canEdit ?? false;
    final needAsync = ref.watch(facadeMaterialsProvider(widget.salesOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(l10n.facadeMaterialsTitle)),
            // Film goes by the press load: the map shows how.
            IconButton(
              key: const ValueKey('orderPressLayout'),
              tooltip: l10n.pressLayoutTitle,
              icon: const Icon(AppIcons.pressLayout),
              onPressed: () =>
                  context.push(Routes.pressLayoutOf(widget.salesOrder)),
            ),
            if (needAsync.value?.fullyHeld ?? false)
              StatusChip(
                label: l10n.facadeMaterialsHeld,
                intent: StatusIntent.success,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        needAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () =>
                ref.invalidate(facadeMaterialsProvider(widget.salesOrder)),
          ),
          data: (need) => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (need.materials.isEmpty && need.unresolved.isEmpty)
                  Text(l10n.facadeMaterialsEmpty),
                for (final row in need.materials) _NeedRow(row: row),
                for (final note in need.unresolved)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      note,
                      style: TextStyle(color: context.statusColors.warning),
                    ),
                  ),
                if (canEdit &&
                    need.materials.any((m) => (m.short ?? 0) > 0)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      key: const ValueKey('facadeMaterialsReserve'),
                      onPressed: _busy ? null : _reserve,
                      child: Text(l10n.facadeMaterialsReserve),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.row});

  final FacadeMaterialNeed row;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = row.unit ?? '';
    final needed = row.needed;
    final short = row.short ?? 0;
    return ListTile(
      key: ValueKey('facadeNeed:${row.kind}:${row.key}'),
      contentPadding: EdgeInsets.zero,
      title: Text(row.title ?? '${row.kind} ${row.key}'),
      subtitle: Text(
        row.note ??
            l10n.facadeMaterialsLine(
              '${_n(needed ?? 0)} $unit',
              '${_n(row.held)} $unit',
              '${_n(row.issued)} $unit',
            ),
      ),
      trailing: row.note == null && short > 0
          ? StatusChip(
              label: l10n.facadeMaterialsShort('${_n(short)} $unit'),
              intent: StatusIntent.danger,
              compact: true,
            )
          : null,
    );
  }
}
