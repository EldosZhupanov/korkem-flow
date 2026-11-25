import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';
import 'package:korkem_flow/features/costs/presentation/costs_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Статьи затрат» — the owner's own list: found by a few letters, added,
/// changed, put in the archive, two that are one merged.
class CostItemsTab extends ConsumerStatefulWidget {
  const CostItemsTab({super.key});

  @override
  ConsumerState<CostItemsTab> createState() => _CostItemsTabState();
}

class _CostItemsTabState extends ConsumerState<CostItemsTab> {
  final _search = TextEditingController();
  bool _archived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(CostCatalog catalog, [CostItem? item]) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ItemDialog(catalog: catalog, item: item),
    );
    if (saved != true) return;
    ref.invalidate(costCatalogProvider);
    messenger.showDone(l10n.cstSaved);
  }

  Future<void> _menu(CostCatalog catalog, CostItem item, String what) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(costsRepositoryProvider);
    try {
      if (what == 'archive') {
        await repo.archive(item.name, archived: !item.archived);
      } else {
        final target = await showDialog<CostItem>(
          context: context,
          builder: (_) => _MergeDialog(catalog: catalog, source: item),
        );
        if (target == null) return;
        await repo.merge(item.name, target.name);
      }
      ref
        ..invalidate(costCatalogProvider)
        ..invalidate(consumablesProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(costCatalogProvider);
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(costCatalogProvider),
      ),
      data: (c) {
        final words = _search.text.trim().toLowerCase();
        final shown = [
          for (final i in c.items)
            if (i.archived == _archived &&
                (words.isEmpty ||
                    i.title.toLowerCase().contains(words) ||
                    i.group.toLowerCase().contains(words)))
              i,
        ];
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ReadableWidth(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('cst:search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(AppIcons.search),
                        hintText: l10n.cstSearch,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    key: const ValueKey('cst:showArchived'),
                    label: Text(l10n.cstShowArchived),
                    selected: _archived,
                    onSelected: (v) => setState(() => _archived = v),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey('cst:addItem'),
                    onPressed: () => _edit(c),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.cstAddItem),
                  ),
                ],
              ),
            ),
            for (final group in c.groups)
              if (shown.any((i) => i.group == group)) ...[
                const SizedBox(height: AppSpacing.md),
                ReadableWidth(child: SectionLabel(group)),
                for (final i in shown)
                  if (i.group == group)
                    ReadableWidth(
                      child: _ItemLine(
                        item: i,
                        onTap: () => _edit(c, i),
                        onMenu: (what) => _menu(c, i, what),
                      ),
                    ),
              ],
          ],
        );
      },
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({
    required this.item,
    required this.onTap,
    required this.onMenu,
  });

  final CostItem item;
  final VoidCallback onTap;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = costMoney(context);
    final i = item;
    return ListTile(
      key: ValueKey('cst:costItem:${i.name}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Row(
        children: [
          Flexible(child: Text(i.title, overflow: TextOverflow.ellipsis)),
          if (i.isNew) ...[
            const SizedBox(width: AppSpacing.xs),
            StatusChip(
              label: l10n.cstNew,
              intent: StatusIntent.info,
              compact: true,
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          modeLabel(i.mode, l10n),
          if (i.fixed) l10n.cstFixed else l10n.cstVariable,
          if (i.area.isNotEmpty) i.area,
          if (i.unit.isNotEmpty) i.unit,
          if (i.monthlyLimit > 0) l10n.cstLimitOf(money.format(i.monthlyLimit)),
        ].join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        key: ValueKey('cst:itemMenu:${i.name}'),
        onSelected: onMenu,
        itemBuilder: (_) => [
          PopupMenuItem(
            key: const ValueKey('cst:archive'),
            value: 'archive',
            child: Text(i.archived ? l10n.cstRestore : l10n.cstArchive),
          ),
          if (!i.archived)
            PopupMenuItem(
              key: const ValueKey('cst:merge'),
              value: 'merge',
              child: Text(l10n.cstMerge),
            ),
        ],
      ),
    );
  }
}

String modeLabel(CostMode mode, AppLocalizations l10n) => switch (mode) {
  CostMode.bill => l10n.cstModeBill,
  CostMode.stock => l10n.cstModeStock,
  CostMode.other => l10n.cstModeOther,
};

/// A cost item, new or changed.
class _ItemDialog extends ConsumerStatefulWidget {
  const _ItemDialog({required this.catalog, this.item});

  final CostCatalog catalog;
  final CostItem? item;

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.item?.title ?? '',
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.item?.unit ?? '',
  );
  late final TextEditingController _limit = TextEditingController(
    text: (widget.item?.monthlyLimit ?? 0) > 0
        ? widget.item!.monthlyLimit.toStringAsFixed(0)
        : '',
  );
  late String _group =
      widget.item?.group ??
      (widget.catalog.groups.length > 1
          ? widget.catalog.groups[1]
          : widget.catalog.groups.first);
  late String _area =
      widget.item?.area ??
      (widget.catalog.areas.isEmpty ? '' : widget.catalog.areas.first);
  late CostMode _mode = widget.item?.mode ?? CostMode.other;
  late bool _fixed = widget.item?.fixed ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _unit.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(costsRepositoryProvider)
          .saveItem(
            name: widget.item?.name,
            title: _title.text.trim(),
            group: _group,
            mode: _mode,
            fixed: _fixed,
            area: _area,
            unit: _unit.text.trim(),
            monthlyLimit: double.tryParse(_limit.text.replaceAll(' ', '')) ?? 0,
          );
      if (mounted) Navigator.of(context).pop(true);
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
    final c = widget.catalog;
    return AlertDialog(
      key: const ValueKey('cst:itemDialog'),
      title: Text(widget.item == null ? l10n.cstAddItem : l10n.cstEditItem),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('cst:itemTitle'),
                controller: _title,
                autofocus: widget.item == null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.cstItemTitle),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey('cst:itemGroup'),
                initialValue: c.groups.contains(_group) ? _group : null,
                decoration: InputDecoration(labelText: l10n.cstGroup),
                items: [
                  for (final g in c.groups)
                    DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: (g) => setState(() => _group = g ?? _group),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.cstMode, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final m in CostMode.values)
                    ChoiceChip(
                      key: ValueKey('cst:mode:${m.name}'),
                      label: Text(modeLabel(m, l10n)),
                      selected: _mode == m,
                      onSelected: (_) => setState(() => _mode = m),
                    ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('cst:itemFixed'),
                contentPadding: EdgeInsets.zero,
                value: _fixed,
                onChanged: (v) => setState(() => _fixed = v),
                title: Text(l10n.cstFixedSwitch),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('cst:itemArea'),
                initialValue: c.areas.contains(_area) ? _area : null,
                decoration: InputDecoration(labelText: l10n.cstArea),
                items: [
                  for (final a in c.areas)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (a) => setState(() => _area = a ?? _area),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('cst:itemUnit'),
                      controller: _unit,
                      decoration: InputDecoration(
                        labelText: l10n.cstUnit,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const ValueKey('cst:itemLimit'),
                      controller: _limit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.cstLimit,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.statusColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cst:itemSave'),
          onPressed: !_busy && _title.text.trim().length >= 2 ? _save : null,
          child: Text(l10n.cstSave),
        ),
      ],
    );
  }
}

/// Which item [source] is the same as — its history goes there.
class _MergeDialog extends StatelessWidget {
  const _MergeDialog({required this.catalog, required this.source});

  final CostCatalog catalog;
  final CostItem source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final others = [
      for (final i in catalog.items)
        if (!i.archived && i.name != source.name) i,
    ]..sort((a, b) => a.title.compareTo(b.title));
    return SimpleDialog(
      key: const ValueKey('cst:mergeDialog'),
      title: Text(l10n.cstMergeHint(source.title)),
      children: [
        for (final i in others)
          SimpleDialogOption(
            key: ValueKey('cst:mergeInto:${i.name}'),
            onPressed: () => Navigator.of(context).pop(i),
            child: Text('${i.title} · ${i.group}'),
          ),
      ],
    );
  }
}
