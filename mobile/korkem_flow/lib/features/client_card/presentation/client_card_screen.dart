import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/pay_helpers.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/client_card/presentation/debt_invoice.dart';
import 'package:korkem_flow/features/client_card/presentation/reconciliation.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_orders_screen.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_customer_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_customers_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One customer on one page (owner, 18.11.2026): who he is, everything he
/// ordered — facades, CNC, film — what he paid and what he still owes; and
/// from here a new order, a sale of film, a message.
///
/// Made to work on (owner, 21.11.2026: «как бы ты настроил?»): two columns
/// on a wide screen — his orders by where they are in the shop, or his
/// history on one line, on the left; what he owes with what to do about it
/// (one payment for all of it, a reminder), his terms, his colours on the
/// right.
class ClientCardScreen extends ConsumerWidget {
  const ClientCardScreen({required this.customer, super.key});

  final String customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final card = ref.watch(clientCardProvider(customer));
    return Scaffold(
      appBar: AppBar(
        title: Text(card.value?.name ?? l10n.clcTitle),
        actions: [
          if (card.value?.phone case final phone?) ...[
            IconButton(
              key: const ValueKey('clc:whatsapp'),
              tooltip: l10n.clcWhatsApp,
              icon: const Icon(AppIcons.whatsApp),
              onPressed: () => unawaited(ContactActions.whatsApp(phone)),
            ),
            IconButton(
              key: const ValueKey('clc:copyPhone'),
              tooltip: l10n.gsrActCopyPhone,
              icon: const Icon(AppIcons.copy),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: phone));
                messenger.showDone(l10n.gsrPhoneCopied);
              },
            ),
          ],
        ],
      ),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(clientCardProvider(customer)),
        ),
        data: (c) => RefreshIndicator(
          onRefresh: () => ref.refresh(clientCardProvider(customer).future),
          child: _Body(card: c),
        ),
      ),
    );
  }
}

enum _Tab { orders, history }

enum _Show { all, ready, work, debt }

/// Where an order is, for the card's groups.
enum _Group { ready, work, draft, handed }

_Group _groupOf(ClientOrder o) => o.draft
    ? _Group.draft
    : o.handedOver
    ? _Group.handed
    : o.ready
    ? _Group.ready
    : _Group.work;

final _day = DateFormat('dd.MM.yyyy');

String _date(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '' : _day.format(d);
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.card});

  final ClientCard card;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  _Tab _tab = _Tab.orders;

  ClientCard get card => widget.card;

  /// Under this width the two columns become one.
  static const double _twoColumns = 1000;
  static const double _side = 380;

  Future<void> _sellFilm() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final FilmCatalog stock;
    try {
      stock = await ref.read(filmDeptRepositoryProvider).stock();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return;
    }
    if (!mounted) return;
    final done = await showFilmSale(context, stock, customer: card.customer);
    if (done ?? false) {
      ref
        ..invalidate(clientCardProvider(card.customer))
        ..invalidate(filmCustomersProvider);
    }
  }

  /// «Повторить №»: his last facade order as a new draft.
  Future<void> _repeat(ClientOrder o) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final order = await ref.read(mdfOrderRepositoryProvider).card(o.name);
      unawaited(router.push(Routes.mdfOrderNew, extra: order));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final figures = card.figures;
    final orders = card.orders;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final last = orders
        ?.where((o) => !o.cnc && !o.draft && o.status != 'cancelled')
        .firstOrNull;
    final head = <Widget>[
      Text(
        [
          ?card.phone,
          ?card.organization,
          if (figures?.first case final first?) l10n.clcSince(_date(first)),
          if (card.terms.source case final s?) mdfCustomerSourceLabel(s, l10n),
        ].join(' · '),
        style: muted,
      ),
      const SizedBox(height: AppSpacing.md),
      if (figures != null)
        FigureRow(
          tiles: [
            FigureTile(
              id: 'clc:orders',
              title: l10n.clcOrders,
              value: '${figures.orders}',
              note: figures.last == null
                  ? null
                  : '${l10n.clcLast}: ${_date(figures.last)}',
            ),
            FigureTile(
              id: 'clc:total',
              title: l10n.clcTotal,
              value: money.format(figures.total),
              note: '${l10n.clcAverage}: ${money.format(figures.average)}',
            ),
            FigureTile(
              id: 'clc:paid',
              title: l10n.clcPaid,
              value: money.format(figures.paid),
            ),
            FigureTile(
              id: 'clc:debt',
              title: l10n.clcDebt,
              value: money.format(figures.debt),
              colour: figures.debt > 0.5 ? status.danger : null,
            ),
          ],
        ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (card.canFacades)
            FilledButton.icon(
              key: const ValueKey('clc:newOrder'),
              onPressed: () => unawaited(
                context.push(
                  Routes.mdfOrderNew,
                  extra: FacadeCustomer(
                    name: card.customer,
                    title: card.name,
                    phone: card.phone,
                  ),
                ),
              ),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.clcNewOrder),
            ),
          if (card.canFacades && last != null)
            OutlinedButton.icon(
              key: const ValueKey('clc:repeat'),
              onPressed: () => unawaited(_repeat(last)),
              icon: const Icon(AppIcons.repeat),
              label: Text(l10n.clcRepeat('${last.number ?? last.name}')),
            ),
          if (card.canFilm)
            OutlinedButton.icon(
              key: const ValueKey('clc:sellFilm'),
              onPressed: () => unawaited(_sellFilm()),
              icon: const Icon(AppIcons.moveOut),
              label: Text(l10n.clcSellFilm),
            ),
          if (card.canFacades)
            OutlinedButton.icon(
              key: const ValueKey('clc:allOrders'),
              onPressed: () =>
                  unawaited(context.push(Routes.mdfOrdersOf(card.name))),
              icon: const Icon(AppIcons.board),
              label: Text(l10n.clcAllOrders),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
    ];
    final tabs = SegmentedButton<_Tab>(
      key: const ValueKey('clc:tabs'),
      segments: [
        ButtonSegment(
          value: _Tab.orders,
          label: Text(l10n.clcOrdersSection),
          icon: const Icon(AppIcons.board),
        ),
        ButtonSegment(
          value: _Tab.history,
          label: Text(l10n.clcHistory),
          icon: const Icon(AppIcons.history),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
    final main = <Widget>[
      if (card.canFacades) ...[
        Align(alignment: Alignment.centerLeft, child: tabs),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (_tab == _Tab.orders || !card.canFacades)
        _Orders(card: card)
      else
        _History(customer: card.customer),
    ];
    final side = _Side(card: card);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _twoColumns) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final w in [
                ...head,
                side,
                const SizedBox(height: AppSpacing.md),
                ...main,
              ])
                ReadableWidth(child: w),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(children: [...head, ...main]),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: _side,
                child: ListView(children: [side]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// His orders by where they are: ready to hand over, in the shop, drafts,
/// handed over — each with its stages, area, what is owed and since when.
class _Orders extends StatefulWidget {
  const _Orders({required this.card});

  final ClientCard card;

  @override
  State<_Orders> createState() => _OrdersState();
}

class _OrdersState extends State<_Orders> {
  _Show _show = _Show.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final orders = [
      for (final o in widget.card.orders ?? const <ClientOrder>[])
        if (o.status != 'cancelled') o,
    ];
    if (widget.card.orders == null) return const SizedBox.shrink();
    if (orders.isEmpty) return Text(l10n.clcNoOrders, style: muted);
    int count(_Show s) => orders.where((o) => _keeps(o, s)).length;
    final shown = [
      for (final o in orders)
        if (_keeps(o, _show)) o,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in _Show.values)
              if (s == _Show.all || count(s) > 0)
                ChoiceChip(
                  key: ValueKey('clc:show:${s.name}'),
                  label: Text('${_showLabel(s, l10n)} ${count(s)}'),
                  selected: _show == s,
                  onSelected: (_) => setState(() => _show = s),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final g in _Group.values)
          if (shown.where((o) => _groupOf(o) == g).toList() case final rows
              when rows.isNotEmpty) ...[
            SectionLabel('${_groupLabel(g, l10n)} · ${rows.length}'),
            for (final o in rows) _OrderRow(order: o),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  static bool _keeps(ClientOrder o, _Show s) => switch (s) {
    _Show.all => true,
    _Show.ready => _groupOf(o) == _Group.ready,
    _Show.work => _groupOf(o) == _Group.work,
    _Show.debt => o.debt > 0.5,
  };

  static String _showLabel(_Show s, AppLocalizations l10n) => switch (s) {
    _Show.all => l10n.clcShowAll,
    _Show.ready => l10n.clcShowReady,
    _Show.work => l10n.clcShowWork,
    _Show.debt => l10n.clcShowDebt,
  };

  static String _groupLabel(_Group g, AppLocalizations l10n) => switch (g) {
    _Group.ready => l10n.clcGroupReady,
    _Group.work => l10n.clcGroupWork,
    _Group.draft => l10n.clcGroupDraft,
    _Group.handed => l10n.clcGroupHanded,
  };
}

/// One order: number, colour, area; its stages — done ticked, the next
/// one marked; what is owed, since when, and a bar of what is paid.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final ClientOrder order;

  /// A debt older than this, days, is said in red.
  static const int _oldDebt = 7;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final o = order;
    final small = theme.textTheme.bodySmall;
    final next = o.stages.indexWhere((s) => !s.done);
    final paidPart = o.total > 0 ? (o.paid / o.total).clamp(0.0, 1.0) : 0.0;
    String area(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1).replaceAll('.', ',');
    return InkWell(
      key: ValueKey('clc:order:${o.name}'),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => unawaited(
        context.push(o.cnc ? Routes.cncOrder(o.name) : Routes.mdfOrder(o.name)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(o.cnc ? AppIcons.workOrder : AppIcons.board),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (o.number case final n?) '№ $n' else o.name,
                      if (o.cnc) l10n.clcCnc,
                      ?o.decor,
                      if (o.area > 0) '${area(o.area)} м²',
                    ].join(' · '),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (o.stages.isEmpty || o.ready || o.handedOver)
                        Text(
                          o.cnc
                              ? cncStatusLabel(CncStatus.parse(o.status), l10n)
                              : mdfStatusChip(
                                  MdfStatus.parse(o.status),
                                  l10n,
                                ).$1,
                          key: ValueKey('clc:status:${o.name}'),
                          style: small?.copyWith(
                            color: o.ready ? status.success : null,
                          ),
                        )
                      else
                        for (final (i, s) in o.stages.indexed)
                          if (MdfStage.parse(s.key) case final stage?)
                            _StageMark(
                              key: ValueKey('clc:stage:${o.name}:${s.key}'),
                              label: mdfStageLabel(stage, l10n),
                              done: s.done,
                              now: i == next,
                            ),
                      if (!o.handedOver && o.due != null)
                        Text(l10n.clcDueBy(_date(o.due)), style: small),
                      if (o.handedOver && o.handedOverOn != null)
                        Text(_date(o.handedOverOn), style: small),
                    ],
                  ),
                  if (o.total > 0 && !o.draft) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: LinearProgressIndicator(
                        key: ValueKey('clc:paidBar:${o.name}'),
                        value: paidPart,
                        minHeight: AppSpacing.xs,
                        color: status.success,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  o.debt > 0.5
                      ? l10n.gsrDebt(money.format(o.debt))
                      : money.format(o.total),
                  style: small?.copyWith(
                    color: o.debt > 0.5 ? status.danger : null,
                  ),
                ),
                if (o.debtDays case final days? when o.debt > 0.5)
                  Text(
                    l10n.clcDebtDays(days),
                    key: ValueKey('clc:debtDays:${o.name}'),
                    style: small?.copyWith(
                      color: days > _oldDebt
                          ? status.danger
                          : theme.colorScheme.onSurfaceVariant,
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

/// A stage on an order's row: done — ticked; the one being worked — marked.
class _StageMark extends StatelessWidget {
  const _StageMark({
    required this.label,
    required this.done,
    required this.now,
    super.key,
  });

  final String label;
  final bool done;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: done || now ? scheme.secondaryContainer : null,
        border: done || now ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          done ? '$label ✓' : label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: done || now
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: now ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}

/// The right column: what he owes and what to do about it, his terms, his
/// colours, film, the last payments.
class _Side extends ConsumerWidget {
  const _Side({required this.card});

  final ClientCard card;

  /// A debt older than this, days, is counted apart.
  static const int _oldDebt = 7;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showDialog<int>(
      context: context,
      builder: (_) => _PayAllDialog(card: card),
    );
    if (done == null) return;
    ref
      ..invalidate(clientCardProvider(card.customer))
      ..invalidate(clientHistoryProvider(card.customer));
    messenger.showDone(l10n.clcPaidSplit(done));
  }

  /// «Счёт на весь долг» (owner, 25.11.2026): made, sent, on the card.
  Future<void> _invoice(BuildContext context, WidgetRef ref) async {
    final made = await showDebtInvoice(context, card);
    if (made != true) return;
    ref
      ..invalidate(clientCardProvider(card.customer))
      ..invalidate(clientHistoryProvider(card.customer));
  }

  Future<void> _remind(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(clientCardRepositoryProvider);
    try {
      final said = await repo.debtText(card.customer);
      if (!context.mounted) return;
      final send = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.clcRemind),
          content: SelectableText(
            said.text,
            key: const ValueKey('clc:remindText'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.mdfCancel),
            ),
            FilledButton.icon(
              key: const ValueKey('clc:remindSend'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(AppIcons.whatsApp),
              label: Text(l10n.clcWhatsApp),
            ),
          ],
        ),
      );
      if (send != true) return;
      unawaited(
        ContactActions.whatsAppMessage(said.phone ?? card.phone, said.text),
      );
      await repo.reminded(card.customer);
      ref
        ..invalidate(clientCardProvider(card.customer))
        ..invalidate(clientHistoryProvider(card.customer));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final figures = card.figures;
    final orders = card.orders ?? const <ClientOrder>[];
    final debt = figures?.debt ?? 0;
    final old = orders
        .where((o) => o.debt > 0.5 && (o.debtDays ?? 0) > _oldDebt)
        .fold<double>(0, (s, o) => s + o.debt);
    final limit = card.limit;
    final colours = <String, int>{};
    for (final o in orders) {
      if (o.decor case final d? when !o.draft) {
        colours[d] = (colours[d] ?? 0) + 1;
      }
    }
    final top = colours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final t = card.terms;
    Widget box(Widget child, {Color? edge}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: edge ?? theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.canFacades && figures != null)
          box(
            edge: debt > 0.5 ? status.danger : null,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.clcDebt, style: muted),
                Text(
                  money.format(debt),
                  key: const ValueKey('clc:debtSum'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: debt > 0.5 ? status.danger : status.success,
                  ),
                ),
                if (limit > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    debt > limit
                        ? l10n.clcLimitOver(
                            money.format(limit),
                            money.format(debt - limit),
                          )
                        : l10n.clcLimit(money.format(limit)),
                    key: const ValueKey('clc:limit'),
                    style: muted?.copyWith(
                      color: debt > limit ? status.danger : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: (debt / limit).clamp(0.0, 1.0),
                      minHeight: AppSpacing.xs,
                      color: debt > limit ? status.danger : status.warning,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
                if (old > 0.5) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.clcOldDebt(_oldDebt, money.format(old)),
                    key: const ValueKey('clc:oldDebt'),
                    style: muted?.copyWith(color: status.danger),
                  ),
                ],
                if (debt > 0.5) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('clc:pay'),
                        onPressed: () => unawaited(_pay(context, ref)),
                        icon: const Icon(AppIcons.payroll),
                        label: Text(l10n.clcPayAll),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('clc:remind'),
                        onPressed: () => unawaited(_remind(context, ref)),
                        icon: const Icon(AppIcons.whatsApp),
                        label: Text(l10n.clcRemind),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('clc:invoice'),
                        onPressed: () => unawaited(_invoice(context, ref)),
                        icon: const Icon(AppIcons.quote),
                        label: Text(l10n.dinvButton),
                      ),
                    ],
                  ),
                ],
                // His debt invoices: waited for, then the last ones done.
                if (card.invoices.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.dinvSection, style: muted),
                  DebtInvoices(card: card),
                ],
                // «Акт сверки» — owing or not, a company asks for it.
                if (figures.orders > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    key: const ValueKey('clc:act'),
                    onPressed: () =>
                        unawaited(showReconciliation(context, card.customer)),
                    icon: const Icon(AppIcons.quote),
                    label: Text(l10n.actTitle),
                  ),
                ],
              ],
            ),
          ),
        if (card.canFacades)
          box(
            Column(
              key: const ValueKey('clc:terms'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.clcTerms, style: muted),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    if (t.discountPct > 0)
                      l10n.clcTermDiscount(
                        t.discountPct == t.discountPct.roundToDouble()
                            ? t.discountPct.toStringAsFixed(0)
                            : t.discountPct.toString(),
                      ),
                    if (t.pricePvcM2 > 0)
                      l10n.clcTermPvc(money.format(t.pricePvcM2)),
                    if (t.pricePaintM2 > 0)
                      l10n.clcTermPaint(money.format(t.pricePaintM2)),
                    if (!t.ownPrice) l10n.clcTermList,
                  ].join(' · '),
                ),
              ],
            ),
          ),
        if (top.isNotEmpty)
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.clcColours, style: muted),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final e in top.take(6))
                      Chip(
                        key: ValueKey('clc:colour:${e.key}'),
                        label: Text('${e.key} ×${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (card.film case final film?)
          box(
            ListTile(
              key: const ValueKey('clc:film'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.material),
              title: Text(l10n.clcFilmOpen),
              subtitle: Text(
                l10n.clcFilmLine(
                  filmMetres(film.totalM),
                  money.format(film.total),
                  money.format(film.debt),
                ),
              ),
              trailing: const Icon(AppIcons.forward),
              onTap: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FilmCustomerPage(customer: film),
                  ),
                ),
              ),
            ),
          ),
        if (card.payments.isNotEmpty)
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.clcPaymentsSection, style: muted),
                for (final p in card.payments.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(AppIcons.payroll),
                    title: Text([_date(p.date), ?p.method].join(' · ')),
                    subtitle: Text(p.order),
                    trailing: Text(
                      money.format(p.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: status.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// «Оплата» for all he owes (owner, 21.11.2026): one sum, a method, and how
/// it falls on his orders — the oldest first. Gives how many orders it
/// went on, or null.
class _PayAllDialog extends ConsumerStatefulWidget {
  const _PayAllDialog({required this.card});

  final ClientCard card;

  @override
  ConsumerState<_PayAllDialog> createState() => _PayAllDialogState();
}

class _PayAllDialogState extends ConsumerState<_PayAllDialog> {
  late final TextEditingController _amount =
      TextEditingController(
          text: (widget.card.figures?.debt ?? 0).toStringAsFixed(0),
        )
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: (widget.card.figures?.debt ?? 0)
              .toStringAsFixed(0)
              .length,
        );
  String _method = 'Перевод';

  /// The debt invoice it is paid by; null — without one.
  String? _invoice;
  bool _busy = false;
  String? _error;

  void _byInvoice(MdfInvoice? i) => setState(() {
    _invoice = i?.no;
    final debt = widget.card.figures?.debt ?? 0;
    final sum = i == null ? debt : (i.left < debt ? i.left : debt);
    _amount.text = sum.toStringAsFixed(0);
  });

  double get _value =>
      double.tryParse(_amount.text.replaceAll(' ', '').replaceAll(',', '.')) ??
      0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final made = await ref
          .read(clientCardRepositoryProvider)
          .pay(
            widget.card.customer,
            amount: _value,
            method: _method,
            invoice: _invoice,
          );
      if (mounted) Navigator.of(context).pop(made.split.length);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final debt = widget.card.figures?.debt ?? 0;
    final value = _value;
    final over = value > debt + 0.5;
    final split = splitOldestFirst(widget.card, value);
    final invoices = widget.card.waitedInvoices;
    return AlertDialog(
      key: const ValueKey('clc:payDialog'),
      title: Text(l10n.clcPayAll),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // «По счёту № 12» — a part of it or the rest of it.
              if (invoices.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('clc:payBy:none'),
                      label: Text(l10n.clcPayNoInvoice),
                      selected: _invoice == null,
                      onSelected: (_) => _byInvoice(null),
                    ),
                    for (final i in invoices)
                      ChoiceChip(
                        key: ValueKey('clc:payBy:${i.no}'),
                        label: Text(
                          l10n.clcPayByInvoice(i.no, money.format(i.left)),
                        ),
                        selected: _invoice == i.no,
                        onSelected: (_) => _byInvoice(i),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                key: const ValueKey('clc:payAmount'),
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.mdfInvoiceSum,
                  helperText: l10n.clcPayOwes(money.format(debt)),
                  errorText: over ? l10n.clcPayOver(money.format(debt)) : null,
                ),
              ),
              // One tap for the whole debt (owner, 26.11.2026).
              if (_invoice == null) ...[
                const SizedBox(height: AppSpacing.xs),
                PayQuickAmounts(
                  options: [
                    (key: 'all', label: l10n.payQuickDebt, amount: debt),
                  ],
                  current: value,
                  format: money.format,
                  onPick: (v) =>
                      setState(() => _amount.text = v.toStringAsFixed(0)),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final (wire, label) in [
                    ('Перевод', l10n.mdfPayTransfer),
                    ('Наличные', l10n.mdfPayCash),
                    ('Карта', l10n.mdfPayCard),
                  ])
                    ChoiceChip(
                      key: ValueKey('clc:payMethod:$wire'),
                      label: Text(label),
                      selected: _method == wire,
                      onSelected: (_) => setState(() => _method = wire),
                    ),
                ],
              ),
              if (_method == 'Наличные' && value > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                PayCashChange(amount: value, format: money.format),
              ],
              if (!over && debt > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                PayAfter(owed: debt, paying: value, format: money.format),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (split.isNotEmpty && !over) ...[
                Text(l10n.clcPaySplit, style: theme.textTheme.labelLarge),
                for (final (o, part) in split)
                  Text(
                    [
                      '№ ${o.number ?? o.name} — ${money.format(part)}',
                      if (part + 0.5 < o.debt)
                        l10n.clcPayPart(money.format(o.debt)),
                    ].join(' '),
                    key: ValueKey('clc:paySplit:${o.name}'),
                  ),
              ],
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('clc:paySave'),
          onPressed: !_busy && value > 0 && !over ? _save : null,
          child: Text(l10n.clcPaySave),
        ),
      ],
    );
  }
}

/// His history on one line, by day (owner, 21.11.2026: «а истории заказа
/// нету ли тут?»), the kinds to narrow it, and a note to add.
class _History extends ConsumerStatefulWidget {
  const _History({required this.customer});

  final String customer;

  @override
  ConsumerState<_History> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<_History> {
  ClientEventKind? _kind;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(clientCardRepositoryProvider)
          .addNote(widget.customer, text);
      _note.clear();
      ref.invalidate(clientHistoryProvider(widget.customer));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final events = ref.watch(clientHistoryProvider(widget.customer));
    final today = _day.format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('clc:note'),
                controller: _note,
                enabled: !_busy,
                onSubmitted: (_) => unawaited(_addNote()),
                decoration: InputDecoration(
                  hintText: l10n.clcNoteHint,
                  prefixIcon: const Icon(AppIcons.edit),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('clc:noteSave'),
              tooltip: l10n.clcNoteSave,
              onPressed: _busy ? null : () => unawaited(_addNote()),
              icon: const Icon(AppIcons.send),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              key: const ValueKey('clc:hist:all'),
              label: Text(l10n.clcShowAll),
              selected: _kind == null,
              onSelected: (_) => setState(() => _kind = null),
            ),
            for (final k in ClientEventKind.values)
              ChoiceChip(
                key: ValueKey('clc:hist:${k.name}'),
                label: Text(switch (k) {
                  ClientEventKind.order => l10n.clcHistOrders,
                  ClientEventKind.money => l10n.clcHistMoney,
                  ClientEventKind.message => l10n.clcHistMessages,
                  ClientEventKind.note => l10n.clcHistNotes,
                }),
                selected: _kind == k,
                onSelected: (on) => setState(() => _kind = on ? k : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...events.when(
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (e, _) => [
            ErrorView(
              error: e,
              onRetry: () =>
                  ref.invalidate(clientHistoryProvider(widget.customer)),
            ),
          ],
          data: (all) {
            final shown = [
              for (final e in all)
                if (_kind == null || e.kind == _kind) e,
            ];
            if (shown.isEmpty) return [Text(l10n.clcHistEmpty, style: muted)];
            final out = <Widget>[];
            String? day;
            for (final (i, e) in shown.indexed) {
              final d = _date(e.day);
              if (d != day) {
                day = d;
                out.add(
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      d == today ? l10n.clcToday : d,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                );
              }
              out.add(
                ListTile(
                  key: ValueKey('clc:event:$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (e.kind) {
                      ClientEventKind.order => AppIcons.board,
                      ClientEventKind.money => AppIcons.payroll,
                      ClientEventKind.message => AppIcons.whatsApp,
                      ClientEventKind.note => AppIcons.edit,
                    },
                    color: switch (e.kind) {
                      ClientEventKind.money => status.success,
                      ClientEventKind.message => theme.colorScheme.primary,
                      _ => null,
                    },
                  ),
                  title: Text(
                    e.number != null && !e.text.contains('№ ${e.number}')
                        ? '№ ${e.number} · ${e.text}'
                        : e.text,
                  ),
                  subtitle: Text(
                    [?e.time, ?e.by].join(' · '),
                    style: muted,
                  ),
                  onTap: e.order == null
                      ? null
                      : () => unawaited(
                          context.push(Routes.mdfOrder(e.order!)),
                        ),
                ),
              );
            }
            return out;
          },
        ),
      ],
    );
  }
}
