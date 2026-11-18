import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/domain/order_scan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/offcuts/data/offcut_repository.dart';
import 'package:korkem_flow/features/offcuts/domain/offcut.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Обрезки» (owner, 18.11.2026): the pieces of MDF sheets put on the shelf
/// with their size and place, so a new order's small parts are cut from
/// them first. What an order can take shows on its card.
class OffcutsScreen extends ConsumerStatefulWidget {
  const OffcutsScreen({super.key});

  @override
  ConsumerState<OffcutsScreen> createState() => _OffcutsScreenState();
}

class _OffcutsScreenState extends ConsumerState<OffcutsScreen> {
  int? _thickness;
  String? _busy;

  Future<void> _run(String key, Future<Object?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = key);
    try {
      await action();
      ref.invalidate(offcutShelfProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _add(OffcutShelf shelf) async {
    final added = await showDialog<_NewOffcut>(
      context: context,
      builder: (_) => _AddDialog(
        thicknesses: shelf.thicknesses,
        thickness: _thickness,
      ),
    );
    if (added == null || !mounted) return;
    await _run(
      'add',
      () => ref
          .read(offcutRepositoryProvider)
          .add(
            thicknessMm: added.thickness,
            lengthMm: added.length,
            widthMm: added.width,
            cell: added.cell,
            note: added.note,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shelf = ref.watch(offcutShelfProvider);
    final repo = ref.read(offcutRepositoryProvider);
    return AppScreen(
      title: l10n.offcutsTitle,
      subtitle: shelf.value == null
          ? null
          : l10n.offcutsSummary(
              shelf.value!.offcuts.length,
              shelf.value!.areaM2.toStringAsFixed(2),
            ),
      actions: [
        if (shelf.value != null)
          FilledButton.icon(
            key: const ValueKey('offcutsAdd'),
            onPressed: _busy == null ? () => _add(shelf.value!) : null,
            icon: const Icon(AppIcons.add),
            label: Text(l10n.offcutsAdd),
          ),
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(offcutShelfProvider),
        ),
      ],
      body: shelf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(offcutShelfProvider),
        ),
        data: (s) {
          final shown = [
            for (final o in s.offcuts)
              if (_thickness == null || o.thicknessMm == _thickness) o,
          ];
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.offcutsAll),
                          selected: _thickness == null,
                          onSelected: (_) => setState(() => _thickness = null),
                        ),
                        for (final t in {
                          ...s.thicknesses,
                          for (final o in s.offcuts) o.thicknessMm,
                        }.toList()..sort())
                          ChoiceChip(
                            key: ValueKey('offcutsThickness:$t'),
                            label: Text(l10n.offcutsMm(t)),
                            selected: _thickness == t,
                            onSelected: (_) => setState(() => _thickness = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (shown.isEmpty)
                      EmptyView(
                        icon: AppIcons.offcut,
                        title: l10n.offcutsEmptyTitle,
                        message: l10n.offcutsEmpty,
                      ),
                    for (final o in shown)
                      _OffcutTile(
                        offcut: o,
                        busy: _busy == o.name,
                        onUse: () => _run(o.name, () => repo.use(o.name)),
                        onScrap: () => _run(o.name, () => repo.scrap(o.name)),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OffcutTile extends StatelessWidget {
  const _OffcutTile({
    required this.offcut,
    required this.busy,
    required this.onUse,
    required this.onScrap,
  });

  final Offcut offcut;
  final bool busy;
  final VoidCallback onUse;
  final VoidCallback onScrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = offcut;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        key: ValueKey('offcut:${o.name}'),
        child: Row(
          children: [
            const Icon(AppIcons.offcut, size: AppIconSize.normal),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.offcutsMm(o.thicknessMm)} · ${o.size}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      if (o.cell != null) l10n.offcutsCell(o.cell!),
                      if (o.sourceOrder != null)
                        l10n.offcutsFrom(orderShortNumber(o.sourceOrder!)),
                      if (o.forOrder != null)
                        l10n.offcutsFor(orderShortNumber(o.forOrder!)),
                      ?o.note,
                      if (o.createdOn != null) mdfDay(o.createdOn),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: AppIconSize.normal,
                child: CircularProgressIndicator(),
              )
            else
              PopupMenuButton<bool>(
                key: ValueKey('offcutMenu:${o.name}'),
                icon: const Icon(AppIcons.more),
                onSelected: (use) => use ? onUse() : onScrap(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: true, child: Text(l10n.offcutsUse)),
                  PopupMenuItem(value: false, child: Text(l10n.offcutsScrap)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

typedef _NewOffcut = ({
  int thickness,
  int length,
  int width,
  String? cell,
  String? note,
});

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.thicknesses, this.thickness});

  final List<int> thicknesses;
  final int? thickness;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  late int? _thickness =
      widget.thickness ??
      (widget.thicknesses.isEmpty ? null : widget.thicknesses.first);
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _cell = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final c in [_length, _width, _cell, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  _NewOffcut? get _value {
    final t = _thickness;
    final l = int.tryParse(_length.text);
    final w = int.tryParse(_width.text);
    if (t == null || l == null || w == null || l <= 0 || w <= 0) return null;
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return (
      thickness: t,
      length: l,
      width: w,
      cell: text(_cell),
      note: text(_note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(l10n.offcutsAddTitle),
      content: SizedBox(
        width: AppBreakpoints.listPaneWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('offcutAddThickness'),
              initialValue: _thickness,
              decoration: InputDecoration(labelText: l10n.offcutsThickness),
              items: [
                for (final t in widget.thicknesses)
                  DropdownMenuItem(value: t, child: Text(l10n.offcutsMm(t))),
              ],
              onChanged: (t) => setState(() => _thickness = t),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('offcutAddLength'),
                    controller: _length,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(labelText: l10n.offcutsLength),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    key: const ValueKey('offcutAddWidth'),
                    controller: _width,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(labelText: l10n.offcutsWidth),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('offcutAddCell'),
              controller: _cell,
              decoration: InputDecoration(
                labelText: l10n.offcutsCellLabel,
                hintText: l10n.offcutsCellHint,
              ),
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.offcutsNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('offcutAddSave'),
          onPressed: _value == null
              ? null
              : () => Navigator.of(context).pop(_value),
          child: Text(l10n.offcutsPut),
        ),
      ],
    );
  }
}

/// On an order's card: the parts an offcut on the shelf holds, with
/// «Взять» (owner, 18.11.2026). Nothing shows when there are none.
class OffcutSuggestionView extends ConsumerStatefulWidget {
  const OffcutSuggestionView({required this.order, super.key});

  final String order;

  @override
  ConsumerState<OffcutSuggestionView> createState() =>
      _OffcutSuggestionViewState();
}

class _OffcutSuggestionViewState extends ConsumerState<OffcutSuggestionView> {
  String? _busy;

  Future<void> _take(OffcutPart part) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = part.offcut.name);
    try {
      await ref
          .read(offcutRepositoryProvider)
          .take(part.offcut.name, widget.order);
      ref
        ..invalidate(offcutSuggestionProvider(widget.order))
        ..invalidate(offcutShelfProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final parts = ref
        .watch(offcutSuggestionProvider(widget.order))
        .value
        ?.parts;
    if (parts == null || parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        key: const ValueKey('offcutSuggestion'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(AppIcons.offcut, size: AppIconSize.small),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.offcutsSuggestTitle(parts.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.offcutsSuggestLine(
                          p.position,
                          '${p.heightMm}×${p.widthMm}',
                          p.offcut.size,
                          p.offcut.cell ?? '—',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      key: ValueKey('offcutTake:${p.offcut.name}'),
                      onPressed: _busy == null ? () => _take(p) : null,
                      child: Text(l10n.offcutsTake),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
