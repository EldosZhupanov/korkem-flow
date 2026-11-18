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
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_orders_screen.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_customer_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One customer on one page (owner, 18.11.2026): who he is, everything he
/// ordered — facades, CNC, film — what he paid and what he still owes; and
/// from here a new order, a sale of film, a message.
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

class _Body extends ConsumerWidget {
  const _Body({required this.card});

  final ClientCard card;

  static final _day = DateFormat('dd.MM.yyyy');

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? '' : _day.format(d);
  }

  Future<void> _sellFilm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final FilmCatalog stock;
    try {
      stock = await ref.read(filmDeptRepositoryProvider).stock();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return;
    }
    if (!context.mounted) return;
    final done = await showFilmSale(context, stock, customer: card.customer);
    if (done ?? false) {
      ref
        ..invalidate(clientCardProvider(card.customer))
        ..invalidate(filmCustomersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final figures = card.figures;
    final orders = card.orders;
    final film = card.film;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Text(
            [
              ?card.phone,
              ?card.organization,
              if (figures?.first case final first?) l10n.clcSince(_date(first)),
            ].join(' · '),
            style: muted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (figures != null)
          ReadableWidth(
            child: FigureRow(
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
          ),
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(
          child: Wrap(
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
              if (card.canFilm)
                OutlinedButton.icon(
                  key: const ValueKey('clc:sellFilm'),
                  onPressed: () => unawaited(_sellFilm(context, ref)),
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
        ),
        if (orders != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.clcOrdersSection)),
          if (orders.isEmpty)
            ReadableWidth(child: Text(l10n.clcNoOrders, style: muted)),
          for (final o in orders)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('clc:order:${o.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(o.cnc ? AppIcons.workOrder : AppIcons.board),
                title: Text(
                  [
                    if (o.number case final n?) '№ $n' else o.name,
                    if (o.cnc) l10n.clcCnc,
                    ?o.decor,
                  ].join(' · '),
                ),
                subtitle: Text(
                  [
                    if (o.cnc)
                      cncStatusLabel(CncStatus.parse(o.status), l10n)
                    else
                      mdfStatusChip(MdfStatus.parse(o.status), l10n).$1,
                    _date(o.createdOn),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                trailing: Text(
                  o.debt > 0.5
                      ? l10n.gsrDebt(money.format(o.debt))
                      : money.format(o.total),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: o.debt > 0.5 ? status.danger : null,
                  ),
                ),
                onTap: () => unawaited(
                  context.push(
                    o.cnc ? Routes.cncOrder(o.name) : Routes.mdfOrder(o.name),
                  ),
                ),
              ),
            ),
        ],
        if (film != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.clcFilmSection)),
          ReadableWidth(
            child: ListTile(
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
        ],
        if (card.payments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.clcPaymentsSection)),
          for (final p in card.payments)
            ReadableWidth(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(AppIcons.payroll),
                title: Text(
                  [_date(p.date), ?p.method].join(' · '),
                ),
                subtitle: Text(p.order),
                trailing: Text(
                  money.format(p.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: status.success,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
