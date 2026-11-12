import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/domain/film_orders.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_pick.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «К заказу» (owner, 12.11.2026: «с утра записал одну плёнку, к 12:00 набил
/// 4 заказа… одним кликом итоговым отчётом за день отправить поставщику»).
///
/// One list that fills up over the day, laid out by supplier. Each
/// supplier's part goes out in one WhatsApp message; when he confirms, the
/// delivery window opens with every film in it, and what was wanted for a
/// customer is put by for him when it comes.
class FilmOrdersPage extends ConsumerWidget {
  const FilmOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wanted = ref.watch(filmWantedProvider);
    final stock = ref.watch(filmStockProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filmOrdersTitle),
        actions: [
          if (wanted.value case final w? when w.canEdit && w.toSend.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton.icon(
                key: const ValueKey('filmOrders:sendAll'),
                onPressed: () => _sendAll(context, ref, w),
                icon: const Icon(AppIcons.whatsApp),
                label: Text(l10n.filmOrdersSendAll(w.toSend.length)),
              ),
            ),
        ],
      ),
      body: wanted.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(filmWantedProvider),
        ),
        data: (w) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.filmOrdersSummary(
                    w.count,
                    filmMetres(w.metres),
                    w.toSend.length,
                  ),
                  key: const ValueKey('filmOrders:summary'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (w.canEdit && stock != null)
                  OutlinedButton.icon(
                    key: const ValueKey('filmOrders:add'),
                    onPressed: () => _add(context, ref, stock),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmOrdersAdd),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (w.groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.filmOrdersEmpty),
              ),
            for (final g in w.groups)
              _GroupCard(group: g, canEdit: w.canEdit, stock: stock),
            if (w.groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.filmOrdersLegend,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    FilmCatalog stock,
  ) async {
    final l10n = AppLocalizations.of(context);
    final film = await showFilmChoice(
      context,
      stock.films,
      title: l10n.filmOrdersAdd,
    );
    if (film == null || !context.mounted) return;
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _AddWantDialog(film: film),
    );
    if (done ?? false) _refreshOrders(ref);
  }

  static Future<void> _sendAll(
    BuildContext context,
    WidgetRef ref,
    FilmWanted w,
  ) async {
    for (final g in w.toSend) {
      if (!context.mounted) return;
      await sendFilmOrder(context, ref, g);
    }
  }
}

void _refreshOrders(WidgetRef ref) => ref
  ..invalidate(filmWantedProvider)
  ..invalidate(filmStockProvider);

/// The message a supplier gets: the films one per line, the total.
String filmOrderText(AppLocalizations l10n, FilmWantGroup g, DateTime day) {
  final films = FilmWantGroup.byFilm(g.open);
  final lines = [
    for (final (i, f) in films.indexed)
      l10n.filmOrderLine(
        i + 1,
        f.first.title,
        filmMetres(f.fold<double>(0, (s, l) => s + l.metres)),
      ),
  ].join('\n');
  return l10n.filmOrderText(
    mdfDayOf(day),
    lines,
    films.length,
    filmMetres(g.openM),
  );
}

/// The supplier's part goes out: WhatsApp opens with the message ready, or
/// — no number on his card — the message is copied; either way the lines
/// wait for his answer now.
Future<void> sendFilmOrder(
  BuildContext context,
  WidgetRef ref,
  FilmWantGroup g,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = filmOrderText(l10n, g, DateTime.now());
  final to = g.writeTo;
  // Marked sent first: a WhatsApp slow to open must not lose the mark.
  try {
    await ref.read(filmOrdersRepositoryProvider).sent(g.supplier);
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  if (to == null) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.filmOrderCopied(g.name))),
    );
  } else {
    unawaited(ContactActions.whatsAppMessage(to, text));
  }
  _refreshOrders(ref);
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({
    required this.group,
    required this.canEdit,
    required this.stock,
  });

  final FilmWantGroup group;
  final bool canEdit;
  final FilmCatalog? stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final g = group;
    final key = g.supplier ?? '-';
    final who = [?g.city, ?g.contact, ?g.phone].join(' · ');
    final sentFilms = FilmWantGroup.byFilm(g.sent);

    Future<void> confirmed() async {
      final s = stock;
      if (s == null) return;
      final done = await showFilmDelivery(
        context,
        s,
        supplier: g.supplier,
        supplierName: g.name,
        wants: [
          for (final f in sentFilms)
            (
              item: f.first.item,
              metres: f.fold<double>(0, (sum, l) => sum + l.metres),
              customer: null,
              customerName: _forWhom(l10n, f),
              orders: [for (final l in f) ?l.id],
            ),
        ],
      );
      if (done ?? false) _refreshOrders(ref);
    }

    return Card(
      key: ValueKey('filmOrders:group:$key'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.supplier == null ? l10n.filmOrdersNoSupplier : g.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (who.isNotEmpty)
                        Text(who, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (g.open.isNotEmpty)
                  Text(
                    l10n.filmOrdersGroupTotal(
                      FilmWantGroup.byFilm(g.open).length,
                      filmMetres(g.openM),
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
              ],
            ),
            if (g.orderUntil != null && g.open.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.filmOrdersUntil(g.orderUntil!),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: status.warning,
                  ),
                ),
              ),
            for (final f in FilmWantGroup.byFilm(g.open))
              _FilmRow(lines: f, canEdit: canEdit),
            if (canEdit && g.open.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey('filmOrders:send:$key'),
                  onPressed: () => sendFilmOrder(context, ref, g),
                  icon: const Icon(AppIcons.whatsApp),
                  label: Text(
                    g.writeTo == null
                        ? l10n.filmOrdersCopy
                        : l10n.filmOrdersSend,
                  ),
                ),
              ),
            if (g.sent.isNotEmpty) ...[
              const Divider(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: status.success.withValues(alpha: AppTint.surface),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.filmOrdersSentAt(
                          (g.sentAt ?? '').length >= 16
                              ? g.sentAt!.substring(11, 16)
                              : g.sentAt ?? '',
                        ),
                        key: ValueKey('filmOrders:sent:$key'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: status.success,
                        ),
                      ),
                      for (final f in sentFilms)
                        Text(
                          l10n.filmOrderLine(
                            sentFilms.indexOf(f) + 1,
                            f.first.title,
                            filmMetres(
                              f.fold<double>(0, (s, l) => s + l.metres),
                            ),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (canEdit)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            key: ValueKey('filmOrders:confirmed:$key'),
                            onPressed: stock == null ? null : confirmed,
                            icon: const Icon(AppIcons.moveIn),
                            label: Text(l10n.filmOrdersConfirmed),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Мебель-ЮГ 20 м, на склад 30 м» — for whom a film's metres are.
String? _forWhom(AppLocalizations l10n, List<FilmWant> lines) {
  if (lines.every((l) => l.customer == null)) return null;
  return [
    for (final l in lines)
      l.customer == null
          ? l10n.filmOrdersForShelf(filmMetres(l.metres))
          : l10n.filmOrdersForCustomer(
              l.customerName ?? l.customer!,
              filmMetres(l.metres),
            ),
  ].join(', ');
}

/// One film on a supplier's list: its metres in all, and each want —
/// whose, how many, when put on — to change or strike off.
class _FilmRow extends ConsumerWidget {
  const _FilmRow({required this.lines, required this.canEdit});

  final List<FilmWant> lines;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final first = lines.first;
    final total = lines.fold<double>(0, (s, l) => s + l.metres);
    final repo = ref.read(filmOrdersRepositoryProvider);

    Future<void> act(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text('$e')));
        }
      }
      _refreshOrders(ref);
    }

    Future<void> change(FilmWant l) async {
      final metres = await showDialog<double>(
        context: context,
        builder: (_) => _MetresDialog(title: l.title, metres: l.metres),
      );
      if (metres == null || metres == l.metres) return;
      final id = l.id;
      if (id != null) {
        await act(() => repo.update(id, metres: metres));
      } else {
        // Offered by itself: on the list now, with the metres said.
        await act(() => repo.add(item: l.item, metres: metres));
      }
    }

    return Padding(
      key: ValueKey('filmOrders:film:${first.item}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.title, style: theme.textTheme.bodyLarge),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final l in lines)
                      InputChip(
                        key: ValueKey('filmOrders:want:${l.id ?? l.item}'),
                        label: Text(
                          [
                            if (l.auto)
                              l10n.filmOrdersRanOut(filmMetres(l.metres))
                            else if (l.customer == null)
                              l10n.filmOrdersForShelf(filmMetres(l.metres))
                            else
                              l10n.filmOrdersForCustomer(
                                l.customerName ?? l.customer!,
                                filmMetres(l.metres),
                              ),
                            ?l.at,
                          ].join(' · '),
                        ),
                        backgroundColor:
                            (l.auto
                                    ? status.danger
                                    : l.customer == null
                                    ? status.neutral
                                    : status.info)
                                .withValues(alpha: AppTint.surface),
                        onPressed: canEdit ? () => change(l) : null,
                        onDeleted: canEdit
                            ? () => act(
                                () => l.id == null
                                    ? repo.drop(item: l.item)
                                    : repo.drop(line: l.id),
                              )
                            : null,
                        deleteIcon: Icon(
                          AppIcons.close,
                          key: ValueKey('filmOrders:drop:${l.id ?? l.item}'),
                        ),
                        deleteButtonTooltipMessage: l10n.filmReceiveRemove,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            l10n.filmSupM(filmMetres(total)),
            key: ValueKey('filmOrders:metres:${first.item}'),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _MetresDialog extends StatefulWidget {
  const _MetresDialog({required this.title, required this.metres});

  final String title;
  final double metres;

  @override
  State<_MetresDialog> createState() => _MetresDialogState();
}

class _MetresDialogState extends State<_MetresDialog> {
  late final _c = TextEditingController(text: filmMetres(widget.metres));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double? get _value =>
      double.tryParse(_c.text.trim().replaceAll(',', '.').replaceAll(' ', ''));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = _value;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('filmOrders:metresField'),
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: l10n.filmMetresLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmOrders:metresSave'),
          onPressed: v == null || v <= 0
              ? null
              : () => Navigator.of(context).pop(v),
          child: Text(l10n.mdfSaveDraft),
        ),
      ],
    );
  }
}

/// A film put on the list: so many metres, for a customer or the shelf.
class _AddWantDialog extends ConsumerStatefulWidget {
  const _AddWantDialog({required this.film});

  final Film film;

  @override
  ConsumerState<_AddWantDialog> createState() => _AddWantDialogState();
}

class _AddWantDialogState extends ConsumerState<_AddWantDialog> {
  final _metres = TextEditingController();
  String? _customer;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _metres.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customers = ref.watch(filmCustomersProvider).value ?? const [];
    final metres = double.tryParse(
      _metres.text.trim().replaceAll(',', '.').replaceAll(' ', ''),
    );
    return AlertDialog(
      title: Text(filmName(widget.film)),
      content: SizedBox(
        width: AppSpacing.xxxl * 7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filmHave(filmMetres(widget.film.free))),
            TextField(
              key: const ValueKey('filmWant:metres'),
              controller: _metres,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.filmMetresLabel),
            ),
            DropdownButtonFormField<String?>(
              key: ValueKey('filmWant:customer:${customers.length}'),
              initialValue: _customer,
              isExpanded: true,
              items: [
                DropdownMenuItem(child: Text(l10n.filmReceiveForShelf)),
                for (final c in customers)
                  DropdownMenuItem(value: c.customer, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _customer = v),
              decoration: InputDecoration(labelText: l10n.filmReceiveForWhom),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmWant:save'),
          onPressed: _busy || metres == null || metres <= 0
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await ref
                        .read(filmOrdersRepositoryProvider)
                        .add(
                          item: widget.film.item,
                          metres: metres,
                          customer: _customer,
                        );
                    if (context.mounted) Navigator.of(context).pop(true);
                  } on Object catch (e) {
                    setState(() {
                      _busy = false;
                      _error = '$e';
                    });
                  }
                },
          child: Text(l10n.filmOrdersAddSave),
        ),
      ],
    );
  }
}

/// The stock's own button: «К заказу · 5», and how many wait for an answer.
class FilmOrdersButton extends ConsumerWidget {
  const FilmOrdersButton({required this.stock, super.key});

  final FilmCatalog stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    return OutlinedButton.icon(
      key: const ValueKey('filmDept:orders'),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FilmOrdersPage()),
        );
        ref.invalidate(filmStockProvider);
      },
      icon: Icon(
        AppIcons.delivery,
        color: stock.wanted > 0 ? status.danger : null,
      ),
      label: Text(
        stock.waiting > 0
            ? l10n.filmOrdersButtonWaiting(stock.wanted, stock.waiting)
            : l10n.filmOrdersButton(stock.wanted),
      ),
    );
  }
}
