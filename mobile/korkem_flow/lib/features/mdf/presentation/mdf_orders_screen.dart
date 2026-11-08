import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The list of MDF orders — OnayBaza's «Тапсырыстар», compact: who, when,
/// what colour, how much, how much is owed, where it is.
class MdfOrdersScreen extends ConsumerStatefulWidget {
  const MdfOrdersScreen({super.key});

  @override
  ConsumerState<MdfOrdersScreen> createState() => _MdfOrdersScreenState();
}

enum _Filter {
  all,
  draft,
  inShop,
  ready,
  overdue,
  debt,
  urgent,
  vip,
  furnitureMaker,
  rework,
}

class _MdfOrdersScreenState extends ConsumerState<MdfOrdersScreen> {
  String _search = '';
  _Filter _filter = _Filter.all;

  MdfListQuery get _query => (
    search: _search,
    status: switch (_filter) {
      _Filter.draft => MdfStatus.draft,
      _Filter.inShop => MdfStatus.inShop,
      _Filter.ready => MdfStatus.ready,
      _ => null,
    },
    overdue: _filter == _Filter.overdue,
    withDebt: _filter == _Filter.debt,
    tag: switch (_filter) {
      _Filter.urgent => MdfOrderTag.urgent.wire,
      _Filter.vip => MdfCustomerTag.vip.wire,
      _Filter.furnitureMaker => MdfCustomerTag.furnitureMaker.wire,
      _Filter.rework => MdfOrderTag.rework.wire,
      _ => null,
    },
  );

  Future<void> _open(String? name) async {
    await context.push(
      name == null ? Routes.mdfOrderNew : Routes.mdfOrder(name),
    );
    ref.invalidate(mdfOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(mdfOrdersProvider(_query));
    String label(_Filter f) => switch (f) {
      _Filter.all => l10n.mdfFilterAll,
      _Filter.draft => l10n.mdfStatusDraft,
      _Filter.inShop => l10n.mdfStatusInShop,
      _Filter.ready => l10n.mdfStatusReady,
      _Filter.overdue => l10n.mdfFilterOverdue,
      _Filter.debt => l10n.mdfFilterDebt,
      _Filter.urgent => l10n.mdfFilterUrgent,
      _Filter.vip => l10n.mdfTagVip,
      _Filter.furnitureMaker => l10n.mdfFilterFurnitureMakers,
      _Filter.rework => l10n.mdfFilterRework,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mdfOrdersTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('mdfNew'),
              onPressed: () => _open(null),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.mdfOrderNew),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: AppSearchField(
              key: const ValueKey('mdfSearch'),
              hintText: l10n.mdfOrderSearch,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: AppSpacing.xxxl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('mdfFilter:${f.name}'),
                      label: Text(label(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(mdfOrdersProvider(_query)),
              ),
              data: (rows) => rows.isEmpty
                  ? EmptyView(
                      title: l10n.mdfEmpty,
                      message: l10n.mdfEmptyHint,
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(mdfOrdersProvider(_query).future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _OrderRow(
                          row: rows[i],
                          onTap: () => _open(rows[i].name),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status label and colour, shared by the list and the card.
(String, StatusIntent) mdfStatusChip(MdfStatus status, AppLocalizations l10n) =>
    switch (status) {
      MdfStatus.draft => (l10n.mdfStatusDraft, StatusIntent.neutral),
      MdfStatus.accepted => (l10n.mdfStatusAccepted, StatusIntent.info),
      MdfStatus.inShop => (l10n.mdfStatusInShop, StatusIntent.info),
      MdfStatus.ready => (l10n.mdfStatusReady, StatusIntent.success),
      MdfStatus.handedOver => (l10n.mdfStatusHandedOver, StatusIntent.success),
      MdfStatus.onHold => (l10n.mdfStatusOnHold, StatusIntent.warning),
      MdfStatus.cancelled => (l10n.mdfStatusCancelled, StatusIntent.neutral),
    };

String mdfStageLabel(MdfStage stage, AppLocalizations l10n) => switch (stage) {
  MdfStage.cut => l10n.mdfStageCut,
  MdfStage.mill => l10n.mdfStageMill,
  MdfStage.sand => l10n.mdfStageSand,
  MdfStage.vacuum => l10n.mdfStageVacuum,
  MdfStage.paint => l10n.mdfStagePaint,
  MdfStage.ready => l10n.mdfStageReady,
};

NumberFormat mdfMoney(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.row, required this.onTap});

  final MdfOrderRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final (status, intent) = mdfStatusChip(row.status, l10n);
    final what = [
      row.decorTop,
      row.milling,
      row.edgeProfile,
      if (row.areaM2 > 0) '${row.areaM2.toStringAsFixed(2)} м²',
    ].whereType<String>().join(' · ');
    return InkWell(
      key: ValueKey('mdfRow:${row.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.name} · ${row.customerName}',
                    // Urgent and still in work: red, and first in the list.
                    style: row.urgent && _inWork(row.status)
                        ? theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          )
                        : theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      '${row.createdOn} → ${row.deliveryDate}',
                      ?row.phone,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (what.isNotEmpty)
                    Text(what, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StatusChip(label: status, intent: intent, compact: true),
                      if (row.stage != null)
                        StatusChip(
                          label: mdfStageLabel(row.stage!, l10n),
                          intent: StatusIntent.neutral,
                          compact: true,
                        ),
                      if (row.overdue)
                        StatusChip(
                          key: ValueKey('mdfOverdue:${row.name}'),
                          label: l10n.mdfOverdue,
                          intent: StatusIntent.danger,
                          compact: true,
                        )
                      else if (row.dueSoon)
                        StatusChip(
                          label: l10n.mdfDueSoon,
                          intent: StatusIntent.warning,
                          compact: true,
                        ),
                      MdfTagBadges(
                        orderTags: row.tags,
                        customerTags: row.customerTags,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money.format(row.total),
                  style: theme.textTheme.titleSmall,
                ),
                if (row.debt > 0)
                  Text(
                    l10n.mdfDebt(money.format(row.debt)),
                    key: ValueKey('mdfDebt:${row.name}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _inWork(MdfStatus s) =>
    s == MdfStatus.accepted || s == MdfStatus.inShop || s == MdfStatus.ready;
