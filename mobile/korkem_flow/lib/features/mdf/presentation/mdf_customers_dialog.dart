import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_tags.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// OnayBaza's «Заказчик» window: name, phone, organisation and tags (VIP,
/// мебельщик, новый, только предоплата), with add, edit
/// and delete. Tapping a customer chooses them; closing returns null.
Future<FacadeCustomer?> showMdfCustomers(
  BuildContext context, {
  String? current,
}) => showDialog<FacadeCustomer>(
  context: context,
  builder: (_) => MdfCustomersDialog(current: current),
);

class MdfCustomersDialog extends ConsumerStatefulWidget {
  const MdfCustomersDialog({this.current, super.key});

  /// The customer already on the order, highlighted.
  final String? current;

  @override
  ConsumerState<MdfCustomersDialog> createState() => _MdfCustomersDialogState();
}

class _MdfCustomersDialogState extends ConsumerState<MdfCustomersDialog> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(MdfOrderRepository repo) call) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await call(ref.read(mdfOrderRepositoryProvider));
      ref.invalidate(mdfCustomersProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_CustomerInput?> _ask(String title, [FacadeCustomer? c]) =>
      showDialog<_CustomerInput>(
        context: context,
        builder: (_) => _CustomerEditDialog(title: title, initial: c),
      );

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final input = await _ask(l10n.mdfDictAdd);
    if (input == null) return;
    await _run(
      (repo) => repo.customerAdd(
        input.name,
        phone: input.phone,
        organization: input.organization,
        tags: input.tags,
      ),
    );
  }

  Future<void> _edit(FacadeCustomer c) async {
    final l10n = AppLocalizations.of(context);
    final input = await _ask(l10n.mdfDictRename, c);
    if (input == null) return;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customers = ref.watch(mdfCustomersProvider);
    final q = _search.text.trim().toLowerCase();
    bool matches(FacadeCustomer c) =>
        q.isEmpty ||
        c.title.toLowerCase().contains(q) ||
        (c.phone ?? '').contains(q) ||
        (c.organization ?? '').toLowerCase().contains(q);
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
        width: AppSpacing.xxxl * 14,
        height: AppSpacing.xxxl * 9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                key: const ValueKey('customerSearch'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.mdfCustomerSearch,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(mdfCustomersProvider),
                ),
                data: (all) {
                  final shown = all.where(matches).toList();
                  if (shown.isEmpty) {
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
                              if (c.tags.isNotEmpty)
                                MdfTagBadges(
                                  customerTags: MdfCustomerTag.parse(c.tags),
                                ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('customerEdit:${c.name}'),
                                tooltip: l10n.mdfDictRename,
                                onPressed: _busy ? null : () => _edit(c),
                                icon: const Icon(AppIcons.edit),
                              ),
                              IconButton(
                                key: ValueKey('customerDelete:${c.name}'),
                                tooltip: l10n.mdfDictDelete,
                                onPressed: _busy ? null : () => _delete(c),
                                icon: const Icon(AppIcons.delete),
                              ),
                            ],
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
});

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({required this.title, this.initial});

  final String title;
  final FacadeCustomer? initial;

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
