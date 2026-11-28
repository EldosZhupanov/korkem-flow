import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_worker_sheet.dart';
import 'package:korkem_flow/features/saw_cutting/data/saw_cutting_repository.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_journal_screen.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_parts_table.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_print.dart';
import 'package:korkem_flow/features/saw_cutting/presentation/saw_sheet_map.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One cutting job (owner, 28.11.2026): the parts typed or imported, the
/// layouts to choose from, each sheet as it lies on the saw with its cuts,
/// the paper map and the labels, each sheet marked sawn — who, what spoilt —
/// and the job's history. [name] null — a new job.
class SawJobScreen extends ConsumerWidget {
  const SawJobScreen({this.name, super.key});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (name == null) {
      final journal = ref.watch(
        sawJournalProvider((filter: JournalFilter.all, search: '')),
      );
      return AppScreen(
        title: l10n.sawNew,
        fullWidth: true,
        body: journal.when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(sawJournalProvider),
          ),
          data: (j) => _JobBody(materials: j.materials),
        ),
      );
    }
    final job = ref.watch(cuttingJobProvider(name!));
    return AppScreen(
      title: job.value?.name ?? name!,
      subtitle: job.value?.title,
      fullWidth: true,
      body: job.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(cuttingJobProvider(name!)),
        ),
        data: (j) => _JobBody(
          key: ValueKey('${j.name}:${j.version}:${j.choice}'),
          job: j,
          materials: [
            SawMaterial(
              item: j.materialItem,
              name: j.material,
              thicknessMm: j.thicknessMm,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobBody extends ConsumerStatefulWidget {
  const _JobBody({required this.materials, this.job, super.key});

  final CuttingJob? job;
  final List<SawMaterial> materials;

  @override
  ConsumerState<_JobBody> createState() => _JobBodyState();
}

class _JobBodyState extends ConsumerState<_JobBody> {
  late final List<SawPartRow> _rows = [
    for (final p in widget.job?.parts ?? const <SawPart>[]) SawPartRow(p),
    if ((widget.job?.parts ?? const []).isEmpty) SawPartRow(),
  ];
  late String? _material =
      widget.job?.materialItem ??
      (widget.materials.length == 1 ? widget.materials.first.item : null);
  late String _choice = widget.job?.choice ?? 'best';
  SawCalculation? _calc;
  bool _dirty = false;
  String? _busy;

  CuttingJob? get _job => widget.job;
  bool get _editable => _job == null || (_job!.editable && _job!.canMake);

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  NumberFormat get _mm =>
      NumberFormat('0.#', Localizations.localeOf(context).toLanguageTag());

  List<SawPart> get _parts => [
    for (final r in _rows)
      if (r.part case final p?) p,
  ];

  void _changed() => setState(() {
    _dirty = true;
    _calc = null;
  });

  void _addRow(int after) {
    final rows = _rows;
    if (after == rows.length - 1) {
      setState(() => rows.add(SawPartRow()));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && after + 1 < rows.length) {
        rows[after + 1].heightFocus.requestFocus();
      }
    });
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = key);
    try {
      await action();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  bool _ready() {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_material == null) {
      messenger.showFailureMessage(l10n.sawPickMaterial);
      return false;
    }
    final halfTyped = _rows.where((r) => !r.empty && r.part == null);
    if (_parts.isEmpty || halfTyped.isNotEmpty) {
      messenger.showFailureMessage(l10n.sawFillAll);
      return false;
    }
    return true;
  }

  Future<void> _calculate() async {
    if (!_ready()) return;
    await _run('calc', () async {
      final calc = await ref
          .read(sawCuttingRepositoryProvider)
          .calculate(_material!, _parts);
      setState(() {
        _calc = calc;
        _choice = calc.choices.isEmpty ? 'best' : calc.choices.first.key;
      });
    });
  }

  Future<void> _save({String? choice}) async {
    if (!_ready()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await _run('save', () async {
      final saved = await ref
          .read(sawCuttingRepositoryProvider)
          .save(
            name: _job?.name,
            materialItem: _material!,
            parts: _parts,
            orders: [
              for (final o in _job?.orders ?? const <JobOrder>[]) o.order,
            ],
            choice: choice ?? _choice,
          );
      ref.invalidate(sawJournalProvider);
      messenger.showDone(l10n.sawSaved);
      if (_job == null) {
        unawaited(router.pushReplacement(Routes.sawJobOf(saved.name)));
      } else {
        ref.invalidate(cuttingJobProvider(saved.name));
      }
    });
  }

  Future<void> _import({required bool file}) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(sawCuttingRepositoryProvider);
    ParsedParts? read;
    if (file) {
      final picked = await ref.read(sawFilePickerProvider).pick();
      if (picked == null || !mounted) return;
      await _run('import', () async {
        read = await repo.parse(file: picked);
      });
    } else {
      final text = await showDialog<String>(
        context: context,
        builder: (_) => const _PasteDialog(),
      );
      if (text == null || text.trim().isEmpty || !mounted) return;
      await _run('import', () async {
        read = await repo.parse(text: text);
      });
    }
    final got = read;
    if (got == null || !mounted) return;
    final take = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportCheck(parsed: got),
    );
    if (take != true || !mounted) return;
    setState(() {
      _rows.removeWhere((r) {
        if (!r.empty) return false;
        r.dispose();
        return true;
      });
      _rows.addAll([for (final p in got.rows) SawPartRow(p)]);
      if (_rows.isEmpty) _rows.add(SawPartRow());
      _dirty = true;
      _calc = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showDone(l10n.sawImportRead(got.rows.length));
  }

  Future<void> _mark(JobSheet sheet) async {
    final job = _job!;
    final l10n = AppLocalizations.of(context);
    if (sheet.done) {
      await _run('mark:${sheet.sheetNo}', () async {
        await ref
            .read(sawCuttingRepositoryProvider)
            .sheetDone(job.name, sheet.sheetNo, done: false);
        ref.invalidate(cuttingJobProvider(job.name));
      });
      return;
    }
    final answer = await showDialog<({String? sawnBy, String defects})>(
      context: context,
      builder: (_) => _MarkDialog(sheetNo: sheet.sheetNo, title: job.name),
    );
    if (answer == null || !mounted) return;
    await _run('mark:${sheet.sheetNo}', () async {
      await ref
          .read(sawCuttingRepositoryProvider)
          .sheetDone(
            job.name,
            sheet.sheetNo,
            sawnBy: answer.sawnBy,
            defects: answer.defects.isEmpty ? null : answer.defects,
          );
      ref
        ..invalidate(cuttingJobProvider(job.name))
        ..invalidate(sawJournalProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showDone(l10n.sawMarkTitle(sheet.sheetNo));
      }
    });
  }

  Future<void> _defect(JobSheet sheet) async {
    final job = _job!;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: AppLocalizations.of(context).sawDefects,
        initial: sheet.defects ?? '',
      ),
    );
    if (text == null || !mounted) return;
    await _run('defect:${sheet.sheetNo}', () async {
      await ref
          .read(sawCuttingRepositoryProvider)
          .noteDefect(job.name, sheet.sheetNo, text);
      ref.invalidate(cuttingJobProvider(job.name));
    });
  }

  Future<void> _check(bool checked) async {
    final job = _job!;
    await _run('check', () async {
      await ref
          .read(sawCuttingRepositoryProvider)
          .check(job.name, checked: checked);
      ref
        ..invalidate(cuttingJobProvider(job.name))
        ..invalidate(sawJournalProvider);
    });
  }

  Future<void> _cancel() async {
    final job = _job!;
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: l10n.sawCancelReason, initial: ''),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    await _run('cancel', () async {
      await ref.read(sawCuttingRepositoryProvider).cancel(job.name, reason);
      ref
        ..invalidate(cuttingJobProvider(job.name))
        ..invalidate(sawJournalProvider);
    });
  }

  Future<void> _print(String what) async {
    final job = _job!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    await _run('print:$what', () async {
      await printSawPdf(
        '${job.name}-$what',
        () => switch (what) {
          'labels' => buildSawLabelsPdf(job, l10n, locale: locale),
          'offcuts' => buildSawOffcutLabelsPdf(job, l10n, locale: locale),
          _ => buildSawMapPdf(job, l10n, locale: locale),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final job = _job;
    final saved = job != null && !_dirty ? job : null;
    final plan = saved != null ? saved.plan : _calc?.plans[_choice];
    final choices = saved?.choices ?? _calc?.choices ?? const <SawChoice>[];
    final height = saved?.saw.sheetHeightMm ?? _calc?.sheetHeightMm ?? 0;
    final width = saved?.saw.sheetWidthMm ?? _calc?.sheetWidthMm ?? 0;
    String choiceText(SawChoice c) {
      final line = l10n.sawChoiceLine(c.sheets, c.fences, c.wastePct.round());
      return '${_choiceName(l10n, c.key)} · $line';
    }

    final edges = sawEdgeMetres(_parts);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (job != null) _Header(job: job),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.materials.isEmpty)
                  Text(l10n.sawNoMaterials)
                else
                  DropdownButtonFormField<String>(
                    key: const ValueKey('sawMaterial'),
                    initialValue: _material,
                    decoration: InputDecoration(labelText: l10n.sawMaterial),
                    items: [
                      for (final m in widget.materials)
                        DropdownMenuItem(value: m.item, child: Text(m.name)),
                    ],
                    onChanged: _editable
                        ? (v) => setState(() {
                            _material = v;
                            _dirty = true;
                            _calc = null;
                          })
                        : null,
                  ),
                const SizedBox(height: AppSpacing.md),
                SawPartsTable(
                  rows: _rows,
                  enabled: _editable,
                  onChanged: _changed,
                  onAddRow: _addRow,
                  onRemove: (i) => setState(() {
                    _rows.removeAt(i).dispose();
                    if (_rows.isEmpty) _rows.add(SawPartRow());
                    _dirty = true;
                    _calc = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  [
                    l10n.sawPartsCount(
                      _parts.fold<int>(0, (s, p) => s + p.qty),
                    ),
                    if (edges.isEmpty)
                      l10n.sawEdgeNone
                    else
                      for (final e in edges.entries)
                        l10n.sawEdgeMetres(
                          _mm.format(e.key),
                          _mm.format(e.value),
                        ),
                  ].join(' · '),
                  key: const ValueKey('sawSummary'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_editable) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.sawEnterHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('sawAddRow'),
                        onPressed: () => _addRow(_rows.length - 1),
                        icon: const Icon(AppIcons.add),
                        label: Text(l10n.sawAddPart),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('sawPaste'),
                        onPressed: _busy == null
                            ? () => _import(file: false)
                            : null,
                        icon: const Icon(AppIcons.paste),
                        label: Text(l10n.sawPaste),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('sawFromFile'),
                        onPressed: _busy == null
                            ? () => _import(file: true)
                            : null,
                        icon: const Icon(AppIcons.fromFile),
                        label: Text(l10n.sawFromFile),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('sawCalculate'),
                        onPressed: _busy == null ? _calculate : null,
                        icon: const Icon(AppIcons.calculate),
                        label: Text(l10n.sawCalculate),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('sawSave'),
                        onPressed: _busy == null && (_dirty || job == null)
                            ? _save
                            : null,
                        icon: const Icon(AppIcons.check),
                        label: Text(l10n.sawSave),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (choices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in choices)
                ChoiceChip(
                  key: ValueKey('sawChoice:${c.key}'),
                  selected: c.key == _choice,
                  label: Text(choiceText(c)),
                  onSelected: (_) {
                    if (c.key == _choice) return;
                    if (saved != null) {
                      if (saved.editable && saved.canMake) {
                        unawaited(_save(choice: c.key));
                      }
                    } else {
                      setState(() => _choice = c.key);
                    }
                  },
                ),
            ],
          ),
        ],
        if (plan != null && plan.tooBig.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.sawTooBig(plan.tooBig.join(', ')),
            style: TextStyle(color: context.statusColors.danger),
          ),
        ],
        if (saved != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _Actions(
            job: saved,
            busy: _busy,
            onCheck: _check,
            onPrint: _print,
            onCancel: _cancel,
          ),
        ],
        if (plan != null)
          for (final (i, sheet) in plan.sheets.indexed)
            _SheetCard(
              key: ValueKey('sawSheet:${i + 1}'),
              index: i,
              total: plan.sheets.length,
              sheet: sheet,
              heightMm: height,
              widthMm: width,
              trimMm: saved?.saw.trimMm ?? _calc?.trimMm ?? 0,
              fence: saved?.saw.fence ?? _calc?.fence ?? FenceSide.left,
              mm: _mm,
              state: saved != null && i < saved.sheets.length
                  ? saved.sheets[i]
                  : null,
              canMark:
                  saved != null &&
                  (saved.status == JobStatus.checked ||
                      saved.status == JobStatus.cutting ||
                      saved.status == JobStatus.done),
              busy: _busy,
              onMark: _mark,
              onDefect: _defect,
            ),
        if (job != null && job.history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.sawHistory),
          for (final e in job.history) _HistoryLine(event: e),
        ],
      ],
    );
  }
}

String _choiceName(AppLocalizations l10n, String key) => switch (key) {
  'fences' => l10n.sawChoiceFences,
  'offcut' => l10n.sawChoiceOffcut,
  _ => l10n.sawChoiceBest,
};

class _Header extends StatelessWidget {
  const _Header({required this.job});

  final CuttingJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (due, dueColour) = sawDueLook(context, job.dueDate);
    final people = [
      if (job.madeBy != null) l10n.sawMadeBy(job.madeBy!),
      if (job.checkedBy != null) l10n.sawCheckedBy(job.checkedBy!),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SawStatusChip(status: job.status),
        Text(l10n.sawVersion(job.version), style: theme.textTheme.bodySmall),
        if (job.dueDate != null) Text(due, style: TextStyle(color: dueColour)),
        Text(job.material, style: theme.textTheme.bodyMedium),
        if (people.isNotEmpty)
          Text(people.join(' · '), style: theme.textTheme.bodySmall),
        if (job.cancelReason != null)
          Text(
            l10n.sawCancelled(job.cancelReason!),
            style: TextStyle(color: context.statusColors.danger),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.job,
    required this.busy,
    required this.onCheck,
    required this.onPrint,
    required this.onCancel,
  });

  final CuttingJob job;
  final String? busy;
  final ValueChanged<bool> onCheck;
  final ValueChanged<String> onPrint;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasOffcuts = job.sheets.any((s) => s.offcuts.isNotEmpty);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (job.canMake && job.status == JobStatus.draft)
          FilledButton.icon(
            key: const ValueKey('sawCheck'),
            onPressed: busy == null ? () => onCheck(true) : null,
            icon: const Icon(AppIcons.approval),
            label: Text(l10n.sawCheck),
          ),
        if (job.canMake && job.status == JobStatus.checked)
          TextButton(
            key: const ValueKey('sawUncheck'),
            onPressed: busy == null ? () => onCheck(false) : null,
            child: Text(l10n.sawUncheck),
          ),
        OutlinedButton.icon(
          key: const ValueKey('sawPrintMap'),
          onPressed: busy == null ? () => onPrint('map') : null,
          icon: const Icon(AppIcons.print),
          label: Text(l10n.sawPrint),
        ),
        OutlinedButton.icon(
          key: const ValueKey('sawPrintLabels'),
          onPressed: busy == null ? () => onPrint('labels') : null,
          icon: const Icon(AppIcons.qrCode),
          label: Text(l10n.sawPrintLabels),
        ),
        if (hasOffcuts)
          OutlinedButton.icon(
            key: const ValueKey('sawPrintOffcuts'),
            onPressed: busy == null ? () => onPrint('offcuts') : null,
            icon: const Icon(AppIcons.offcut),
            label: Text(l10n.sawPrintOffcuts),
          ),
        if (job.canMake &&
            job.status != JobStatus.done &&
            job.status != JobStatus.cancelled)
          TextButton(
            key: const ValueKey('sawCancel'),
            onPressed: busy == null ? onCancel : null,
            child: Text(l10n.sawCancel),
          ),
      ],
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.index,
    required this.total,
    required this.sheet,
    required this.heightMm,
    required this.widthMm,
    required this.trimMm,
    required this.fence,
    required this.mm,
    required this.state,
    required this.canMark,
    required this.busy,
    required this.onMark,
    required this.onDefect,
    super.key,
  });

  final int index;
  final int total;
  final SawPlanSheet sheet;
  final double heightMm;
  final double widthMm;
  final double trimMm;
  final FenceSide fence;
  final NumberFormat mm;
  final JobSheet? state;
  final bool canMark;
  final String? busy;
  final ValueChanged<JobSheet> onMark;
  final ValueChanged<JobSheet> onDefect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = context.statusColors;
    final done = state?.done ?? false;
    final map = SawSheetMap(
      sheet: sheet,
      heightMm: heightMm,
      widthMm: widthMm,
      trimMm: trimMm,
      fence: fence,
    );
    final cuts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sawPrintCuts, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final (i, cut) in sheet.cuts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(
              _cutLine(l10n, sheet.cuts, i, mm),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: cut.kind == SawCutKind.strip
                    ? FontWeight.w700
                    : null,
              ),
            ),
          ),
        for (final o in sheet.offcuts)
          Text(
            l10n.sawOffcutToShelf(
              '${mm.format(o.width > o.height ? o.width : o.height)} × '
              '${mm.format(o.width > o.height ? o.height : o.width)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: s.success),
          ),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sawSheetOf(index + 1, total),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  l10n.sawFences(sheet.fences),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (state != null && done)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  [
                    if (state!.sawnByName != null)
                      l10n.sawSawnBy(
                        state!.sawnByName!,
                        (state!.sawnAt ?? '').split('.').first,
                      )
                    else
                      l10n.sawSawnByNobody,
                    if (state!.defects != null)
                      '${l10n.sawDefectNote}: ${state!.defects}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state!.defects != null ? s.danger : s.success,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, box) => box.maxWidth >= AppBreakpoints.compact
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: map),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(flex: 2, child: cuts),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        map,
                        const SizedBox(height: AppSpacing.md),
                        cuts,
                      ],
                    ),
            ),
            if (state != null && canMark) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (done)
                    TextButton(
                      key: ValueKey('sawUnmark:${index + 1}'),
                      onPressed: busy == null ? () => onMark(state!) : null,
                      child: Text(l10n.sawUnmark),
                    )
                  else
                    FilledButton.icon(
                      key: ValueKey('sawMark:${index + 1}'),
                      onPressed: busy == null ? () => onMark(state!) : null,
                      icon: const Icon(AppIcons.check),
                      label: Text(l10n.sawMarkDone),
                    ),
                  if (done)
                    TextButton(
                      key: ValueKey('sawDefect:${index + 1}'),
                      onPressed: busy == null ? () => onDefect(state!) : null,
                      child: Text(l10n.sawDefectNote),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _cutLine(
  AppLocalizations l10n,
  List<SawCut> cuts,
  int i,
  NumberFormat mm,
) {
  final cut = cuts[i];
  final same = cut.kind != SawCutKind.trim && sawSameFence(cuts, i);
  final tail = same ? ' · ${l10n.sawSameFence}' : '';
  return '${i + 1}. ${sawCutText(l10n, cut, mm)}$tail';
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.event});

  final JobEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final what = switch (event.action) {
      'job_saved' => l10n.sawHistSaved(event.version ?? 1),
      'job_checked' => l10n.sawHistChecked,
      'job_unchecked' => l10n.sawHistUnchecked,
      'sheet_done' => l10n.sawHistSheetDone(event.sheet ?? 0),
      'sheet_undone' => l10n.sawHistSheetUndone(event.sheet ?? 0),
      'defect_noted' => l10n.sawHistDefect(event.sheet ?? 0),
      'job_cancelled' => l10n.sawHistCancelled,
      'job_merged' => l10n.sawHistMerged(event.into ?? ''),
      _ => event.action,
    };
    final extra = [
      if (event.sawnBy != null) event.sawnBy!,
      if (event.defects != null) event.defects!,
      if (event.reason != null) event.reason!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${event.at}  ',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (event.who != null) TextSpan(text: '${event.who}: '),
            TextSpan(text: what),
            if (extra.isNotEmpty) TextSpan(text: ' · ${extra.join(' · ')}'),
          ],
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sawPasteTitle),
      content: SizedBox(
        width: AppBreakpoints.compact,
        child: TextField(
          key: const ValueKey('sawPasteText'),
          controller: _text,
          autofocus: true,
          minLines: 6,
          maxLines: 14,
          decoration: InputDecoration(hintText: l10n.sawPasteHint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('sawPasteRead'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l10n.sawImportReadAction),
        ),
      ],
    );
  }
}

String _importLine(SawPart p) {
  final size = '${p.height.toStringAsFixed(0)} × ${p.width.toStringAsFixed(0)}';
  return p.name.isEmpty ? '$size × ${p.qty}' : '$size × ${p.qty}  ${p.name}';
}

class _ImportCheck extends StatelessWidget {
  const _ImportCheck({required this.parsed});

  final ParsedParts parsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final danger = context.statusColors.danger;
    String problem(ImportProblem p) => switch (p) {
      ImportProblem.noSize => l10n.sawProblemNoSize,
      ImportProblem.noWidth => l10n.sawProblemNoWidth,
      ImportProblem.size => l10n.sawProblemSize,
      ImportProblem.qty => l10n.sawProblemQty,
    };
    return AlertDialog(
      title: Text(l10n.sawImportRead(parsed.rows.length)),
      content: SizedBox(
        width: AppBreakpoints.compact,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in parsed.rows.take(30)) Text(_importLine(p)),
            if (parsed.rows.length > 30) const Text('…'),
            if (parsed.errors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.sawImportProblems,
                style: TextStyle(color: danger, fontWeight: FontWeight.w700),
              ),
              for (final e in parsed.errors)
                Text(
                  '${e.line}: ${e.text} — ${problem(e.problem)}',
                  style: TextStyle(color: danger),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('sawImportTake'),
          onPressed: parsed.rows.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text(l10n.sawImportAdd),
        ),
      ],
    );
  }
}

/// «Лист N распилен»: who sawed it — the cutting post's person when not
/// said, as a stage tick does — and what was spoilt, from the paper map.
class _MarkDialog extends ConsumerStatefulWidget {
  const _MarkDialog({required this.sheetNo, required this.title});

  final int sheetNo;
  final String title;

  @override
  ConsumerState<_MarkDialog> createState() => _MarkDialogState();
}

class _MarkDialogState extends ConsumerState<_MarkDialog> {
  final _defects = TextEditingController();
  MdfCrewMember? _who;

  @override
  void dispose() {
    _defects.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final picked = await pickMdfCrew(
      context,
      l10n.sawWho,
      stage: MdfStage.cut,
    );
    if (picked == null || picked.members.isEmpty || !mounted) return;
    setState(() => _who = picked.members.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sawMarkTitle(widget.sheetNo)),
      content: SizedBox(
        width: AppBreakpoints.compact,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: const ValueKey('sawWho'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.profile),
              title: Text(_who?.name ?? l10n.sawWhoDefault),
              subtitle: Text(l10n.sawWho),
              trailing: TextButton(
                onPressed: _pick,
                child: Text(l10n.sawPickWho),
              ),
            ),
            TextField(
              key: const ValueKey('sawDefectsField'),
              controller: _defects,
              decoration: InputDecoration(labelText: l10n.sawDefects),
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
          key: const ValueKey('sawMarkConfirm'),
          onPressed: () => Navigator.of(
            context,
          ).pop((sawnBy: _who?.employee, defects: _defects.text.trim())),
          child: Text(l10n.sawMarkDone),
        ),
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('sawTextField'),
        controller: _text,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('sawTextSave'),
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
