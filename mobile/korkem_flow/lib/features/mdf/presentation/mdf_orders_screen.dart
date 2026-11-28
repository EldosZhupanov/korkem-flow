import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/settings/folds.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_order_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_summary_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_worker_sheet.dart';
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

  /// A stage ticked with nobody named (owner, 28.11.2026) — shown only
  /// while there are some.
  noDoer,
}

class _MdfOrdersScreenState extends ConsumerState<MdfOrdersScreen> {
  late String _search = widget.search ?? '';
  _Filter _filter = _Filter.all;

  /// Each section's head — a chip on top jumps to it (owner, 26.11.2026).
  final Map<MdfListSection, GlobalKey> _heads = {
    for (final s in MdfListSection.values) s: GlobalKey(),
  };

  /// The big sections opened in full; the rest show their first few.
  final _opened = <MdfListSection>{};

  /// A section longer than this shows [_folded] rows and «ещё N».
  static const _foldOver = 10;
  static const _folded = 5;

  /// «Строки»: one line an order, kept between openings.
  static const _denseKey = 'mdf.list.dense';

  void _jump(MdfListSection section) {
    final at = _heads[section]?.currentContext;
    if (at != null) {
      unawaited(Scrollable.ensureVisible(at, duration: AppDuration.standard));
    }
  }

  /// «Оплата» on the row: the order's own payment window.
  Future<void> _pay(MdfOrderRow row) async {
    final paid = await showMdfPaymentFor(context, ref, row.name);
    if (paid) {
      ref
        ..invalidate(mdfOrdersProvider)
        ..invalidate(mdfOverviewProvider);
    }
  }

  /// A stage on the row's bar tapped (owner, 26.11.2026, variant Б): not
  /// done — ticked, and the ones before it with it if asked; done — the
  /// tick taken off, asked first.
  ///
  /// Who did it is never asked first (owner, 28.11.2026: «чтобы он не
  /// просил»): the server names the one it is given to, or the only person
  /// on its post. When it cannot, the snack bar says so and «Кто делал»
  /// names him — or the stage waits in «Без исполнителя».
  Future<void> _tapStage(
    MdfOrderRow row,
    MdfStage stage, {
    required bool done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(mdfOrderRepositoryProvider);
    final label = mdfStageLabel(stage, l10n);
    void refresh() => ref
      ..invalidate(mdfOrdersProvider)
      ..invalidate(mdfOverviewProvider)
      ..invalidate(mdfOrderProvider(row.name));
    if (done) {
      final sure = await _confirm(
        l10n.mdfStageUndoAsk(label),
        l10n.mdfStageUndoYes,
        key: 'mdfStageUndoYes',
      );
      if (!sure) return;
      try {
        await repo.setStage(row.name, stage, done: false);
      } on Object catch (error) {
        messenger.showFailure(error, l10n);
        return;
      }
      refresh();
      return;
    }
    // A stage is not skipped: those before it, not done, go with it.
    final at = row.stages.indexWhere((s) => s.stage == stage);
    final ticks = [
      for (final s in row.stages.take(at + 1))
        if (!s.done) s,
    ];
    if (ticks.length > 1) {
      final sure = await _confirm(
        l10n.mdfStageManyAsk(
          [for (final s in ticks) mdfStageLabel(s.stage, l10n)].join(', '),
        ),
        l10n.mdfStageManyYes,
        key: 'mdfStageManyYes',
      );
      if (!sure) return;
    }
    final ticked = <MdfStage>[];
    MdfOrder? card;
    try {
      for (final s in ticks) {
        card = await repo.setStage(row.name, s.stage, done: true);
        ticked.add(s.stage);
      }
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
    refresh();
    if (ticked.isEmpty) return;
    final names = [for (final t in ticked) mdfStageLabel(t, l10n)].join(', ');
    // The stages the server could name nobody for.
    final nobody = [
      for (final t in ticked)
        if (card?.stageWorkers[t] == null) t,
    ];
    final who = {for (final t in ticked) ?card?.stageWorkers[t]};
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('mdfStageDoneSnack'),
        // With an action a snack bar stays until closed (Flutter 3.38+):
        // it would follow the person to every screen (owner, 27.11.2026).
        persist: false,
        content: Row(
          children: [
            Expanded(
              child: Text(
                nobody.isNotEmpty
                    ? l10n.mdfRowStageNoDoer(row.name, names)
                    : who.isEmpty
                    ? l10n.mdfRowStageDone(row.name, names)
                    : l10n.mdfRowStageDoneWho(row.name, names, who.join(', ')),
              ),
            ),
            // «Кто делал» next to «Отменить» — a tick can always be taken
            // back (owner, 28.11.2026: «бывают разные моменты»).
            if (nobody.isNotEmpty)
              TextButton(
                key: const ValueKey('mdfStageDoerAction'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                ),
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  unawaited(_nameDoers(row, nobody));
                },
                child: Text(l10n.mdfDoerSet),
              ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.mdfRowUndo,
          onPressed: () async {
            for (final t in ticked.reversed) {
              await repo.setStage(row.name, t, done: false);
            }
            refresh();
          },
        ),
      ),
    );
  }

  /// «Кто делал» from the snack bar: one sheet for all the stages just
  /// ticked with nobody named — the same people mostly do them together.
  Future<void> _nameDoers(MdfOrderRow row, List<MdfStage> stages) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(mdfOrderRepositoryProvider);
    final pick = await pickMdfCrew(
      context,
      '${row.name} · ${[for (final s in stages) mdfStageLabel(s, l10n)].join(', ')}',
      order: row.name,
      stage: stages.first,
      areaM2: row.areaM2,
    );
    if (pick == null || pick.members.isEmpty) return;
    try {
      for (final s in stages) {
        await repo.setDoer(row.name, s, pick.single, crew: pick.crew);
      }
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
    ref
      ..invalidate(mdfOrdersProvider)
      ..invalidate(mdfOverviewProvider)
      ..invalidate(mdfOrderProvider(row.name));
  }

  Future<bool> _confirm(String text, String yes, {required String key}) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: ValueKey(key),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;

  Widget _row(MdfOrderRow row, {required bool dense}) => _OrderRow(
    row: row,
    dense: dense,
    onTap: () => _open(row.name),
    onPay: row.debt > 0 && row.status != MdfStatus.draft
        ? () => _pay(row)
        : null,
    onStage: row.status == MdfStatus.draft || row.status == MdfStatus.onHold
        ? null
        : (stage, {required done}) =>
              unawaited(_tapStage(row, stage, done: done)),
    onCall: row.phone == null
        ? null
        : () => unawaited(ContactActions.call(row.phone)),
  );

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
    noDoer: _filter == _Filter.noDoer,
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
        // With an action a snack bar stays until closed (Flutter 3.38+):
        // it would follow the person to every screen (owner, 27.11.2026).
        persist: false,
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
    final dense = ref.watch(foldsProvider).contains(_denseKey);
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
      _Filter.noDoer => l10n.mdfFilterNoDoer('${overview?.withoutDoer ?? 0}'),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mdfOrdersTitle),
        actions: [
          // «Карточки / Строки» (owner, 26.11.2026): 15 orders a screen.
          IconButton(
            key: const ValueKey('mdfDense'),
            tooltip: dense ? l10n.mdfViewCards : l10n.mdfViewRows,
            isSelected: dense,
            icon: Icon(dense ? AppIcons.viewCards : AppIcons.viewRows),
            onPressed: () =>
                ref.read(foldsProvider.notifier).set(_denseKey, shut: !dense),
          ),
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
          // «Узкое место» (owner, 26.11.2026): the stage most late orders
          // wait at — the cause, not 22 rows.
          if (overview?.bottleneck case final b?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: _Bottleneck(
                b: b,
                onShow: () => setState(() => _filter = _Filter.overdue),
                onPlan: () => unawaited(context.push(Routes.mdfPlan)),
              ),
            ),
          SizedBox(
            height: AppSpacing.xxxl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final f in _Filter.values)
                  if (f != _Filter.noDoer ||
                      _filter == f ||
                      (overview?.withoutDoer ?? 0) > 0)
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
                                    child: _row(row, dense: dense),
                                  ),
                              ];
                            }(),
                          // The sections as chips: a tap jumps there.
                          if (sectioned)
                            Wrap(
                              key: const ValueKey('mdfJumps'),
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final section in MdfListSection.values)
                                  if (rows.any((r) => r.section == section))
                                    ActionChip(
                                      key: ValueKey('mdfJump:${section.name}'),
                                      label: Text(
                                        '${sectionTitle(section)} · ${[
                                          for (final r in rows)
                                            if (r.section == section) r,
                                        ].length}',
                                      ),
                                      onPressed: () => _jump(section),
                                    ),
                              ],
                            ),
                          for (final section in MdfListSection.values)
                            if (sectioned)
                              ...() {
                                final all = [
                                  for (final r in rows)
                                    if (r.section == section) r,
                                ];
                                final folded =
                                    all.length > _foldOver &&
                                    !_opened.contains(section);
                                final shown = folded
                                    ? all.take(_folded).toList()
                                    : all;
                                return [
                                  for (final (i, row) in shown.indexed) ...[
                                    if (i == 0)
                                      KeyedSubtree(
                                        key: _heads[section],
                                        child: Padding(
                                          key: ValueKey(
                                            'mdfSection:${section.name}',
                                          ),
                                          padding: const EdgeInsets.only(
                                            top: AppSpacing.md,
                                          ),
                                          child: SectionLabel(
                                            '${sectionTitle(section)} · '
                                            '${all.length}',
                                          ),
                                        ),
                                      )
                                    else
                                      Divider(
                                        height: dense
                                            ? AppStroke.hairline / 2
                                            : AppStroke.hairline,
                                      ),
                                    _row(row, dense: dense),
                                  ],
                                  if (folded)
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: TextButton.icon(
                                        key: ValueKey(
                                          'mdfMore:${section.name}',
                                        ),
                                        icon: const Icon(AppIcons.expand),
                                        label: Text(
                                          l10n.mdfSectionMore(
                                            all.length - _folded,
                                          ),
                                        ),
                                        onPressed: () => setState(
                                          () => _opened.add(section),
                                        ),
                                      ),
                                    ),
                                ];
                              }(),
                          if (!sectioned)
                            for (final (i, row) in rows.indexed) ...[
                              if (i > 0)
                                const Divider(height: AppStroke.hairline),
                              _row(row, dense: dense),
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
/// The row's stages, each a piece of the bar with its name under it; a
/// tap ticks it or takes the tick off (owner, 26.11.2026, variant Б).
class _StageBar extends StatelessWidget {
  const _StageBar({required this.row, this.onStage, this.short = false});

  final MdfOrderRow row;
  final void Function(MdfStage stage, {required bool done})? onStage;

  /// One line an order: the bar alone, the names in the tooltips.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final tap = row.status == MdfStatus.onHold ? null : onStage;
    Color colour(({MdfStage stage, bool done, bool given}) s) => s.done
        ? status.success
        : s.stage == row.waiting
        ? status.info
        : theme.colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, s) in row.stages.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Tooltip(
                  message: s.done
                      ? l10n.mdfStageTapUndo(mdfStageLabel(s.stage, l10n))
                      : l10n.mdfStageTapDone(mdfStageLabel(s.stage, l10n)),
                  child: InkWell(
                    key: ValueKey('mdfBar:${row.name}:${s.stage.name}'),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    onTap: tap == null
                        ? null
                        : () => tap(s.stage, done: s.done),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: colour(s),
                              borderRadius: BorderRadius.circular(
                                AppRadius.xs,
                              ),
                            ),
                          ),
                          if (!short)
                            Text(
                              '${s.done ? '✓' : ''}'
                              '${mdfStageShort(s.stage, l10n)}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: s.done || s.stage == row.waiting
                                    ? colour(s)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!short) ...[
          const SizedBox(height: AppSpacing.xxs),
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
      ],
    );
  }
}

/// A stage's name short enough for the bar: Рас · ЧПУ · Шл · Вак · Гот.
String mdfStageShort(MdfStage stage, AppLocalizations l10n) => switch (stage) {
  MdfStage.cut => l10n.mdfStageShortCut,
  MdfStage.mill => l10n.mdfStageShortMill,
  MdfStage.sand => l10n.mdfStageShortSand,
  MdfStage.vacuum => l10n.mdfStageShortVacuum,
  MdfStage.paint => l10n.mdfStageShortPaint,
  MdfStage.ready => l10n.mdfStageShortReady,
};

class _OrderRow extends StatefulWidget {
  const _OrderRow({
    required this.row,
    required this.onTap,
    this.dense = false,
    this.onPay,
    this.onStage,
    this.onCall,
  });

  final MdfOrderRow row;
  final VoidCallback onTap;

  /// «Строки»: one line (owner, 26.11.2026).
  final bool dense;

  /// The row's own actions — no need to open the card for one tick.
  final VoidCallback? onPay;
  final VoidCallback? onCall;

  /// A stage on the bar tapped — ticked, or the tick taken off (owner,
  /// 26.11.2026: «одним кликом, не заходя в заказ»).
  final void Function(MdfStage stage, {required bool done})? onStage;

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _hover = false;

  MdfOrderRow get row => widget.row;

  /// Oplata, the stage done, a call: under the pointer on a wide screen,
  /// behind «⋮» on a phone.
  List<(Key, IconData, String, VoidCallback)> _actions(AppLocalizations l10n) =>
      [
        if (widget.onPay case final pay?)
          (
            ValueKey('mdfRowPay:${row.name}'),
            AppIcons.payment,
            l10n.mdfRowPay,
            pay,
          ),
        if (widget.onCall case final call?)
          (
            ValueKey('mdfRowCall:${row.name}'),
            AppIcons.call,
            l10n.mdfRowCall,
            call,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = _actions(l10n);
    final wideScreen =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;
    final body = widget.dense ? _dense(context) : _full(context);
    if (actions.isEmpty) return body;
    if (!wideScreen) {
      return Row(
        children: [
          Expanded(child: body),
          PopupMenuButton<int>(
            key: ValueKey('mdfRowMenu:${row.name}'),
            icon: const Icon(AppIcons.more),
            onSelected: (i) => actions[i].$4(),
            itemBuilder: (_) => [
              for (final (i, a) in actions.indexed)
                PopupMenuItem(
                  key: a.$1,
                  value: i,
                  child: ListTile(
                    leading: Icon(a.$2),
                    title: Text(a.$3),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: body,
    );
  }

  /// Payment and a call under the row, at its right (owner, 26.11.2026):
  /// they no longer cover the stages. The room is kept, so the row does not
  /// jump when the pointer comes.
  Widget _buttons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = _actions(l10n);
    final wideScreen =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;
    if (actions.isEmpty || !wideScreen) return const SizedBox.shrink();
    return Visibility(
      key: ValueKey('mdfRowActions:${row.name}'),
      visible: _hover,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions)
            TextButton.icon(
              key: a.$1,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
              ),
              onPressed: _hover ? a.$4 : null,
              icon: Icon(a.$2, size: AppIconSize.dense),
              label: Text(a.$3),
            ),
        ],
      ),
    );
  }

  /// One line an order: who, when, what, where it is, what it costs.
  Widget _dense(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final left = row.daysLeft;
    final small = theme.textTheme.bodySmall;
    return InkWell(
      key: ValueKey('mdfRow:${row.name}'),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                '${row.name.split('-').last} · ${row.customerName}',
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${mdfDay(row.createdOn)} → ${mdfDay(row.deliveryDate)}',
                style: small,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                [
                  ?row.decorTop,
                  if (row.areaM2 > 0) '${row.areaM2.toStringAsFixed(2)} м²',
                ].join(' · '),
                style: small,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: AppSpacing.xxxl * 2,
              child: row.overdue && left != null && left < 0
                  ? Text(
                      l10n.mdfRowLate('${-left}'),
                      key: ValueKey('mdfOverdue:${row.name}'),
                      style: small?.copyWith(color: theme.colorScheme.error),
                    )
                  : const SizedBox.shrink(),
            ),
            if (row.stages.isNotEmpty)
              SizedBox(
                width: AppSpacing.xxxl * 3,
                child: _StageBar(
                  row: row,
                  onStage: widget.onStage,
                  short: true,
                ),
              ),
            _buttons(context),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: AppSpacing.xxxl * 2.5,
              child: Text(
                row.debt > 0
                    ? l10n.mdfDebt(money.format(row.debt))
                    : money.format(row.total),
                key: row.debt > 0 ? ValueKey('mdfDebt:${row.name}') : null,
                textAlign: TextAlign.end,
                style: small?.copyWith(
                  color: row.debt > 0 ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _full(BuildContext context) {
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
      onTap: widget.onTap,
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
                  child: _StageBar(row: row, onStage: widget.onStage),
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
                // Payment and a call: at the row's right, under its figures.
                _buttons(context),
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

/// «Узкое место» (owner, 26.11.2026): most late orders wait at one stage —
/// say so, with the whole queue before it.
class _Bottleneck extends StatelessWidget {
  const _Bottleneck({
    required this.b,
    required this.onShow,
    required this.onPlan,
  });

  final MdfBottleneck b;
  final VoidCallback onShow;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final danger = context.statusColors.danger;
    final stage = mdfStageLabel(b.stage, l10n);
    return Container(
      key: const ValueKey('mdfBottleneck'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: AppTint.surface),
        border: Border.all(color: danger),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(AppIcons.danger, color: danger, size: AppIconSize.small),
          Text(
            l10n.mdfBottleneck(b.late, b.lateTotal, stage),
            style: theme.textTheme.titleSmall?.copyWith(color: danger),
          ),
          Text(
            l10n.mdfBottleneckQueue(
              stage,
              b.queueOrders,
              b.queueM2.toStringAsFixed(1).replaceAll('.', ','),
            ),
            style: theme.textTheme.bodySmall,
          ),
          TextButton(
            key: const ValueKey('mdfBottleneckShow'),
            onPressed: onShow,
            child: Text(l10n.mdfBottleneckShow),
          ),
          TextButton(
            key: const ValueKey('mdfBottleneckPlan'),
            onPressed: onPlan,
            child: Text(l10n.mdfBottleneckPlan),
          ),
        ],
      ),
    );
  }
}
