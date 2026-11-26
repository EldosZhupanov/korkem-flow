import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_summary_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The list of MDF orders — OnayBaza's «Тапсырыстар», compact: who, when,
/// what colour, how much, how much is owed, where it is.
class MdfOrdersScreen extends ConsumerStatefulWidget {
  const MdfOrdersScreen({this.search, super.key});

  /// What to look for at once — the general search opens one customer's
  /// orders this way (owner, 18.11.2026).
  final String? search;

  @override
  ConsumerState<MdfOrdersScreen> createState() => _MdfOrdersScreenState();
}

enum _Filter {
  all,
  draft,
  inShop,
  ready,
  overdue,
  dueSoon,
  debt,
  urgent,
  vip,
  furnitureMaker,
  rework,
}

class _MdfOrdersScreenState extends ConsumerState<MdfOrdersScreen> {
  late String _search = widget.search ?? '';
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
    dueSoon: _filter == _Filter.dueSoon,
    tag: switch (_filter) {
      _Filter.urgent => MdfOrderTag.urgent.wire,
      _Filter.vip => MdfCustomerTag.vip.wire,
      _Filter.furnitureMaker => MdfCustomerTag.furnitureMaker.wire,
      _Filter.rework => MdfOrderTag.rework.wire,
      _ => null,
    },
  );

  Future<void> _open(String? name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final before = ref.read(mdfRecentOrdersProvider).firstOrNull;
    await context.push(
      name == null ? Routes.mdfOrderNew : Routes.mdfOrder(name),
    );
    ref
      ..invalidate(mdfOrdersProvider)
      ..invalidate(mdfOverviewProvider);
    // Back from a new or just accepted order: say it is here (26.11.2026).
    final now = ref.read(mdfRecentOrdersProvider).firstOrNull;
    if (!mounted || now == null || now == before) return;
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('mdfJustSaved'),
        content: Text(l10n.mdfJustSaved(now)),
        action: SnackBarAction(
          label: l10n.mdfJustOpen,
          onPressed: () => unawaited(_open(now)),
        ),
      ),
    );
  }

  /// A figure tapped narrows the list to it; tapped again, back to all.
  void _toggle(_Filter f) =>
      setState(() => _filter = _filter == f ? _Filter.all : f);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(mdfOrdersProvider(_query));
    final overview = ref.watch(mdfOverviewProvider).value;
    final money = mdfMoney(context);
    final status = context.statusColors;
    // Read top-down by what burns, when nothing narrows the list.
    final sectioned = _filter == _Filter.all && _search.trim().isEmpty;
    final recent = ref.watch(mdfRecentOrdersProvider);
    String sectionTitle(MdfListSection section) => switch (section) {
      MdfListSection.overdue => l10n.mdfSectionOverdue,
      MdfListSection.soon => l10n.mdfSectionSoon,
      MdfListSection.shop => l10n.mdfSectionShop,
      MdfListSection.ready => l10n.mdfSectionReady,
      MdfListSection.draft => l10n.mdfSectionDraft,
      MdfListSection.closed => l10n.mdfSectionClosed,
    };
    String label(_Filter f) => switch (f) {
      _Filter.all => l10n.mdfFilterAll,
      _Filter.draft => l10n.mdfStatusDraft,
      _Filter.inShop => l10n.mdfStatusInShop,
      _Filter.ready => l10n.mdfStatusReady,
      _Filter.overdue => l10n.mdfFilterOverdue,
      _Filter.dueSoon => l10n.mdfFilterDueSoon,
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
          // «Итоги МДФ» (owner, 12.11.2026).
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: OutlinedButton.icon(
              key: const ValueKey('mdfSummary'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MdfSummaryScreen(),
                ),
              ),
              icon: const Icon(AppIcons.dashboard),
              label: Text(l10n.mdfOrdersSummary),
            ),
          ),
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
              initialValue: widget.search,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // The four figures (owner, 14.11.2026): what is late, what is due,
          // what waits for its customer, what is owed — a tap narrows the
          // list to it.
          if (overview != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  for (final (i, (f, title, value, note, colour)) in [
                    (
                      _Filter.overdue,
                      l10n.mdfKpiOverdue,
                      '${overview.overdue}',
                      null,
                      overview.overdue > 0 ? status.danger : null,
                    ),
                    (
                      _Filter.dueSoon,
                      l10n.mdfKpiDueSoon,
                      '${overview.dueSoon}',
                      null,
                      overview.dueSoon > 0 ? status.warning : null,
                    ),
                    (
                      _Filter.ready,
                      l10n.mdfKpiReady,
                      '${overview.ready}',
                      null,
                      overview.ready > 0 ? status.success : null,
                    ),
                    (
                      _Filter.debt,
                      l10n.mdfKpiDebt,
                      money.format(overview.debt),
                      l10n.mdfKpiDebtors('${overview.debtors}'),
                      null,
                    ),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Kpi(
                        k: f.name,
                        title: title,
                        value: value,
                        note: note,
                        colour: colour,
                        selected: _filter == f,
                        onTap: () => _toggle(f),
                      ),
                    ),
                  ],
                ],
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
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          // «Только что»: what was accepted or saved now —
                          // it stays in its own section below as well.
                          if (sectioned)
                            ...() {
                              final mine = [
                                for (final n in recent)
                                  ?rows.where((r) => r.name == n).firstOrNull,
                              ];
                              return [
                                if (mine.isNotEmpty)
                                  Row(
                                    key: const ValueKey('mdfSection:recent'),
                                    children: [
                                      Expanded(
                                        child: SectionLabel(l10n.mdfJustNow),
                                      ),
                                      IconButton(
                                        key: const ValueKey('mdfRecentClear'),
                                        tooltip: l10n.mdfJustNowClear,
                                        icon: const Icon(
                                          AppIcons.close,
                                          size: AppIconSize.dense,
                                        ),
                                        onPressed: () => ref
                                            .read(
                                              mdfRecentOrdersProvider.notifier,
                                            )
                                            .clear(),
                                      ),
                                    ],
                                  ),
                                for (final row in mine)
                                  DecoratedBox(
                                    key: ValueKey('mdfRecent:${row.name}'),
                                    decoration: BoxDecoration(
                                      color: status.success.withValues(
                                        alpha: AppTint.surface,
                                      ),
                                      border: Border.all(color: status.success),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                    ),
                                    child: _OrderRow(
                                      row: row,
                                      onTap: () => _open(row.name),
                                    ),
                                  ),
                              ];
                            }(),
                          for (final section in MdfListSection.values)
                            if (sectioned)
                              for (final (i, row)
                                  in rows
                                      .where((r) => r.section == section)
                                      .indexed) ...[
                                if (i == 0)
                                  Padding(
                                    key: ValueKey(
                                      'mdfSection:${section.name}',
                                    ),
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: SectionLabel(sectionTitle(section)),
                                  )
                                else
                                  const Divider(height: AppStroke.hairline),
                                _OrderRow(
                                  row: row,
                                  onTap: () => _open(row.name),
                                ),
                              ],
                          if (!sectioned)
                            for (final (i, row) in rows.indexed) ...[
                              if (i > 0)
                                const Divider(height: AppStroke.hairline),
                              _OrderRow(
                                row: row,
                                onTap: () => _open(row.name),
                              ),
                            ],
                        ],
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

/// One of the four figures over the list; a tap narrows the list to it.
class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.k,
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
    this.note,
    this.colour,
  });

  final String k;
  final String title;
  final String value;
  final String? note;
  final Color? colour;
  final bool selected;
  final VoidCallback onTap;

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
        key: ValueKey('mdfKpi:$k'),
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
                key: ValueKey('mdfKpi:$k:value'),
                style: theme.textTheme.titleLarge?.copyWith(color: colour),
                overflow: TextOverflow.ellipsis,
              ),
              if (note != null) Text(note!, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The order's stages as a bar: done, the one it waits at, what is ahead.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.row});

  final MdfOrderRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final (i, s) in row.stages.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Tooltip(
                  message: mdfStageLabel(s.stage, l10n),
                  child: Container(
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: s.done
                          ? status.success
                          : s.stage == row.waiting
                          ? status.info
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          switch (row.status) {
            MdfStatus.ready => l10n.mdfSectionReady,
            MdfStatus.onHold => l10n.mdfStatusOnHold,
            _ when row.waiting != null => l10n.mdfRowNowAt(
              mdfStageLabel(row.waiting!, l10n),
            ),
            _ => mdfStatusChip(row.status, l10n).$1,
          },
          key: ValueKey('mdfNowAt:${row.name}'),
          style: theme.textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

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
    final left = row.daysLeft;
    final wide =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.compact &&
        row.stages.isNotEmpty;
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
                  // One red thing per row — its lateness — not the whole
                  // title: a list of red titles says nothing (14.11.2026).
                  // Who the customer is, right by his name (owner,
                  // 15.11.2026): VIP, мебельщик — whom not to keep waiting.
                  Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${row.name} · ${row.customerName}',
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (row.customerTags.isNotEmpty)
                        MdfTagBadges(
                          key: ValueKey('mdfRowCustomer:${row.name}'),
                          customerTags: row.customerTags,
                        ),
                    ],
                  ),
                  Text(
                    [
                      '${mdfDay(row.createdOn)} → ${mdfDay(row.deliveryDate)}',
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
                      if (!wide)
                        StatusChip(
                          label: status,
                          intent: intent,
                          compact: true,
                        ),
                      if (row.overdue)
                        StatusChip(
                          key: ValueKey('mdfOverdue:${row.name}'),
                          label: left != null && left < 0
                              ? l10n.mdfRowLate('${-left}')
                              : l10n.mdfOverdue,
                          intent: StatusIntent.danger,
                          compact: true,
                        )
                      else if (row.readyDays != null)
                        StatusChip(
                          label: l10n.mdfRowReadyFor('${row.readyDays}'),
                          intent: StatusIntent.success,
                          compact: true,
                        )
                      else if (left != null && _inWork(row.status))
                        StatusChip(
                          label: left == 0
                              ? l10n.mdfRowToday
                              : l10n.mdfRowDaysLeft('$left'),
                          intent: row.dueSoon
                              ? StatusIntent.warning
                              : StatusIntent.neutral,
                          compact: true,
                        )
                      else if (row.dueSoon)
                        StatusChip(
                          label: l10n.mdfDueSoon,
                          intent: StatusIntent.warning,
                          compact: true,
                        ),
                      MdfTagBadges(orderTags: row.tags),
                    ],
                  ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: AppSpacing.xxxl * 4,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _StageBar(row: row),
                ),
              ),
            ],
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
                  )
                else if (row.status != MdfStatus.draft && row.total > 0)
                  Text(l10n.mdfRowPaid, style: theme.textTheme.bodySmall),
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
