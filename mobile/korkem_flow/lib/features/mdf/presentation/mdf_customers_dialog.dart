import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_coating.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// OnayBaza's «Заказчик» window: name, phone, organisation and tags (VIP,
/// мебельщик, новый, только предоплата), with add and edit. Tapping a
/// customer chooses them; closing returns null.
Future<FacadeCustomer?> showMdfCustomers(
  BuildContext context, {
  String? current,
}) async => (await showMdfCustomerChoice(context, current: current))?.customer;

/// A customer chosen, and whether his last order is to be repeated.
typedef MdfCustomerChoice = ({FacadeCustomer customer, bool repeat});

/// The same window with «Повторить прошлый» on a customer who has orders
/// (owner, 20.11.2026) — the new order's form takes his last coatings,
/// millings and object.
Future<MdfCustomerChoice?> showMdfCustomerChoice(
  BuildContext context, {
  String? current,
  bool repeat = false,
}) => showDialog<MdfCustomerChoice>(
  context: context,
  builder: (_) => MdfCustomersDialog(current: current, repeat: repeat),
);

/// Which customers the window shows (owner, 20.11.2026).
enum MdfCustomerShow { recent, vip, debt, work, idle }

/// «Давно не заказывал»: his last order this many days ago or more.
const int mdfIdleDays = 90;

/// A name and a phone read off what was typed into the search — for
/// «Добавить клиента …» when nobody is found.
({String name, String? phone}) mdfCustomerFromSearch(String text) {
  final digits = Phone.digits(text);
  // Typed as 8 701…, 7 701… or 701…: the last ten digits are the number.
  final phone = digits.length >= 10
      ? Phone.pretty('+7${digits.substring(digits.length - 10)}')
      : null;
  final name = (phone == null ? text : text.replaceAll(RegExp(r'[\d+()\-]'), ''))
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');
  return (name: name, phone: phone);
}

String _last10(String? phone) {
  final d = Phone.digits(phone ?? '');
  return d.length <= 10 ? d : d.substring(d.length - 10);
}

class MdfCustomersDialog extends ConsumerStatefulWidget {
  const MdfCustomersDialog({this.current, this.repeat = false, super.key});

  /// The customer already on the order, highlighted.
  final String? current;

  /// «Повторить прошлый» offered on each customer with orders.
  final bool repeat;

  @override
  ConsumerState<MdfCustomersDialog> createState() => _MdfCustomersDialogState();
}

class _MdfCustomersDialogState extends ConsumerState<MdfCustomersDialog> {
  final _search = TextEditingController();
  bool _busy = false;
  MdfCustomerShow _show = MdfCustomerShow.recent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<T?> _run<T>(Future<T> Function(MdfOrderRepository repo) call) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final out = await call(ref.read(mdfOrderRepositoryProvider));
      ref.invalidate(mdfCustomersProvider);
      return out;
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_CustomerInput?> _ask(String title, [FacadeCustomer? c]) =>
      showDialog<_CustomerInput>(
        context: context,
        builder: (_) => _CustomerEditDialog(
          title: title,
          initial: c,
          // A customer typed into the search is a new one, not an edit.
          deletable: c != null && c.name.isNotEmpty,
        ),
      );

  void _choose(FacadeCustomer c, {bool repeat = false}) =>
      Navigator.of(context).pop((customer: c, repeat: repeat));

  /// «+»: a new customer — unless his phone is already someone's, then that
  /// someone is offered (owner, 20.11.2026: one person, one history).
  Future<void> _add([FacadeCustomer? typed]) async {
    final l10n = AppLocalizations.of(context);
    final input = await _ask(l10n.mdfDictAdd, typed);
    if (input == null || !mounted) return;
    final all = ref.read(mdfCustomersProvider).value ?? const [];
    final phone = _last10(input.phone);
    final same = phone.length < 10
        ? null
        : all.where((c) => _last10(c.phone) == phone).firstOrNull;
    if (same != null) {
      final take = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.mdfCustomerSamePhone(same.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('customerSameTake'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.mdfCustomerTakeHim),
            ),
          ],
        ),
      );
      if ((take ?? false) && mounted) _choose(same);
      return;
    }
    final made = await _run(
      (repo) => repo.customerAdd(
        input.name,
        phone: input.phone,
        organization: input.organization,
        tags: input.tags,
      ),
    );
    // Added from the order: he is the one chosen.
    if (made != null && mounted && typed != null) _choose(made);
  }

  Future<void> _edit(FacadeCustomer c) async {
    final l10n = AppLocalizations.of(context);
    final input = await _ask(l10n.mdfDictRename, c);
    if (input == null) return;
    if (input.delete) {
      await _delete(c);
      return;
    }
    await _run(
      (repo) => repo.customerUpdate(
        c.name,
        input.name,
        phone: input.phone,
        organization: input.organization,
        tags: input.tags,
      ),
    );
  }

  Future<void> _delete(FacadeCustomer c) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.mdfCustomerDeleteAsk(c.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('customerDeleteYes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mdfDictDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _run((repo) => repo.customerRemove(c.name));
  }

  /// His card — orders, payments, colours — over the order's form.
  void _card(FacadeCustomer c) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(Routes.clientCard(c.name)));
  }

  bool _idle(FacadeCustomer c) {
    final last = DateTime.tryParse(c.lastOn ?? '');
    return last != null &&
        DateTime.now().difference(last).inDays >= mdfIdleDays;
  }

  bool _shows(FacadeCustomer c) => switch (_show) {
    MdfCustomerShow.recent => true,
    MdfCustomerShow.vip => MdfCustomerTag.parse(
      c.tags,
    ).contains(MdfCustomerTag.vip),
    MdfCustomerShow.debt => c.debt > 0,
    MdfCustomerShow.work => c.inWork > 0,
    MdfCustomerShow.idle => _idle(c),
  };

  String _showLabel(MdfCustomerShow s, AppLocalizations l10n) => switch (s) {
    MdfCustomerShow.recent => l10n.mdfCustomerShowRecent,
    MdfCustomerShow.vip => l10n.mdfCustomerShowVip,
    MdfCustomerShow.debt => l10n.mdfCustomerShowDebt,
    MdfCustomerShow.work => l10n.mdfCustomerShowWork,
    MdfCustomerShow.idle => l10n.mdfCustomerShowIdle,
  };

  /// «последний 12.11 · ПВХ Палома, Модерн · заказов: 14».
  String _lastLine(FacadeCustomer c, AppLocalizations l10n) {
    final what = [
      for (final g in c.lastGroups)
        [
          if (MdfCoating.parse(g.coating) case final coating?)
            mdfCoatingLabel(coating, l10n),
          ?g.film,
        ].join(' '),
      ...c.lastMillings,
    ].where((s) => s.isNotEmpty).join(', ');
    return l10n.mdfCustomerLast(
      mdfDay(c.lastOn, year: false),
      what.isEmpty ? '—' : what,
      c.orders,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final customers = ref.watch(mdfCustomersProvider);
    final typed = _search.text.trim();
    final q = typed.toLowerCase();
    final qDigits = Phone.digits(typed);
    bool matches(FacadeCustomer c) =>
        q.isEmpty ||
        c.title.toLowerCase().contains(q) ||
        (qDigits.length >= 3 && Phone.digits(c.phone ?? '').contains(qDigits)) ||
        (c.organization ?? '').toLowerCase().contains(q) ||
        c.objects.any((o) => o.toLowerCase().contains(q)) ||
        c.orderNames.any((o) => o.toLowerCase().contains(q));
    Widget badge(String text, Color tone, String key) => Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: AppTint.surface),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.mdfCustomers)),
          IconButton(
            key: const ValueKey('customerAdd'),
            tooltip: l10n.mdfDictAdd,
            onPressed: _busy ? null : _add,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      content: SizedBox(
        width: AppSpacing.xxxl * 16,
        height: AppSpacing.xxxl * 10,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                key: const ValueKey('customerSearch'),
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.mdfCustomerSearchWide,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in MdfCustomerShow.values)
                      ChoiceChip(
                        key: ValueKey('customerShow:${s.name}'),
                        label: Text(_showLabel(s, l10n)),
                        selected: _show == s,
                        onSelected: (_) => setState(() => _show = s),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(mdfCustomersProvider),
                ),
                data: (all) {
                  // The latest buyers first; the rest by name.
                  final shown = [
                    for (final c in all)
                      if (_shows(c) && matches(c)) c,
                  ]..sort((a, b) {
                      final byDay = (b.lastOn ?? '').compareTo(a.lastOn ?? '');
                      return byDay != 0 ? byDay : a.title.compareTo(b.title);
                    });
                  final addTyped = typed.isNotEmpty && shown.isEmpty;
                  if (shown.isEmpty && !addTyped) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          all.isEmpty
                              ? l10n.mdfDictEmpty
                              : l10n.mdfNothingFound,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final parsed = mdfCustomerFromSearch(typed);
                  return ListView(
                    children: [
                      for (final c in shown)
                        ListTile(
                          key: ValueKey('customer:${c.name}'),
                          dense: true,
                          selected: c.name == widget.current,
                          title: Text(c.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [?c.phone, ?c.organization].join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                              if (c.orders > 0)
                                Text(
                                  _lastLine(c, l10n),
                                  key: ValueKey('customerLast:${c.name}'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (c.tags.isNotEmpty)
                                    MdfTagBadges(
                                      customerTags: MdfCustomerTag.parse(
                                        c.tags,
                                      ),
                                    ),
                                  if (c.debt > 0)
                                    badge(
                                      l10n.mdfCustomerDebt(
                                        money.format(c.debt),
                                      ),
                                      status.danger,
                                      'customerDebt:${c.name}',
                                    ),
                                  if (c.inWork > 0)
                                    badge(
                                      l10n.mdfCustomerInWork(c.inWork),
                                      status.warning,
                                      'customerWork:${c.name}',
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _choose(c),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.repeat && c.lastOrder != null)
                                TextButton.icon(
                                  key: ValueKey('customerRepeat:${c.name}'),
                                  onPressed: () => _choose(c, repeat: true),
                                  icon: const Icon(AppIcons.repeat),
                                  label: Text(l10n.mdfCustomerRepeat),
                                ),
                              if (c.phone != null)
                                IconButton(
                                  key: ValueKey('customerWhatsApp:${c.name}'),
                                  tooltip: l10n.mdfCustomerWhatsApp,
                                  onPressed: () => unawaited(
                                    ContactActions.whatsApp(c.phone),
                                  ),
                                  icon: const Icon(AppIcons.whatsApp),
                                ),
                              IconButton(
                                key: ValueKey('customerCard:${c.name}'),
                                tooltip: l10n.mdfCustomerCard,
                                onPressed: () => _card(c),
                                icon: const Icon(AppIcons.info),
                              ),
                              IconButton(
                                key: ValueKey('customerEdit:${c.name}'),
                                tooltip: l10n.mdfDictRename,
                                onPressed: _busy ? null : () => _edit(c),
                                icon: const Icon(AppIcons.edit),
                              ),
                            ],
                          ),
                        ),
                      if (addTyped)
                        ListTile(
                          key: const ValueKey('customerAddTyped'),
                          leading: const Icon(AppIcons.add),
                          title: Text(
                            l10n.mdfCustomerAddTyped(
                              parsed.name.isEmpty ? '—' : parsed.name,
                              parsed.phone ?? '',
                            ),
                          ),
                          onTap: _busy
                              ? null
                              : () => _add(
                                  FacadeCustomer(
                                    name: '',
                                    title: parsed.name,
                                    phone: parsed.phone,
                                  ),
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

typedef _CustomerInput = ({
  String name,
  String? phone,
  String? organization,
  List<String> tags,

  /// «Удалить» pressed: the rest is not read.
  bool delete,
});

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({
    required this.title,
    this.initial,
    this.deletable = false,
  });

  final String title;
  final FacadeCustomer? initial;

  /// «Удалить» here, not beside the name in the list, where one slip of the
  /// finger removed a customer (owner, 20.11.2026).
  final bool deletable;

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late final _name = TextEditingController(text: widget.initial?.title ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _org = TextEditingController(
    text: widget.initial?.organization ?? '',
  );
  late final Set<MdfCustomerTag> _tags = {
    ...MdfCustomerTag.parse(widget.initial?.tags ?? const <String>[]),
  };

  @override
  void dispose() {
    for (final c in [_name, _phone, _org]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _or(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _save() {
    if (_name.text.trim().length < 2) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      phone: _or(_phone),
      organization: _or(_org),
      tags: [
        for (final t in MdfCustomerTag.values)
          if (_tags.contains(t)) t.wire,
      ],
      delete: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('customerName'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.mdfCustomerName),
            ),
            TextField(
              key: const ValueKey('customerPhone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: const [PhoneMaskFormatter()],
              decoration: InputDecoration(labelText: l10n.mdfCustomerPhone),
            ),
            TextField(
              key: const ValueKey('customerOrg'),
              controller: _org,
              decoration: InputDecoration(labelText: l10n.mdfCustomerOrg),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final t in MdfCustomerTag.values)
                    FilterChip(
                      key: ValueKey('customerTag:${t.wire}'),
                      label: Text(mdfCustomerTagLabel(t, l10n)),
                      selected: _tags.contains(t),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _tags.add(t);
                        } else {
                          _tags.remove(t);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.deletable)
          TextButton(
            key: const ValueKey('customerDelete'),
            onPressed: () => Navigator.of(context).pop((
              name: '',
              phone: null,
              organization: null,
              tags: const <String>[],
              delete: true,
            )),
            child: Text(
              l10n.mdfDictDelete,
              style: TextStyle(color: context.statusColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('customerSave'),
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
