import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/cnc_patterns/data/cnc_patterns_repository.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_facade_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Numbers typed with a comma or a dot.
double? cncNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// «1,5» rather than «1.5»; whole numbers without a tail.
String cncFmt(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceAll('.', ',');

/// A pattern edited on the left, drawn on a facade on the right — the cut is
/// seen before anything is saved (owner, 18.11.2026: «узоры ЧПУ»).
class CncPatternEditor extends ConsumerStatefulWidget {
  const CncPatternEditor({
    required this.status,
    this.pattern,
    this.debounce = AppDebounce.search,
    super.key,
  });

  final CncStatus status;

  /// Null for a new pattern.
  final CncPattern? pattern;
  final Duration debounce;

  @override
  ConsumerState<CncPatternEditor> createState() => _CncPatternEditorState();
}

class _CncPatternEditorState extends ConsumerState<CncPatternEditor> {
  late CncPattern _p =
      widget.pattern ??
      CncPattern(
        name: '',
        elements: [
          CncElement(
            kind: CncElementKind.frame,
            tool: widget.status.tools.firstOrNull?.name ?? '',
          ),
        ],
      );
  double _w = 500;
  double _h = 700;
  CncPreview? _preview;
  Object? _error;
  bool _loading = false;
  bool _busy = false;
  Timer? _timer;
  int _asked = 0;

  bool get _manage => widget.status.canManage;

  @override
  void initState() {
    super.initState();
    _schedule(now: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _edit(CncPattern p) {
    setState(() => _p = p);
    _schedule();
  }

  void _element(int i, CncElement e) => _edit(
    CncPattern(
      name: _p.name,
      milling: _p.milling,
      minW: _p.minW,
      minH: _p.minH,
      fallback: _p.fallback,
      example: _p.example,
      elements: [..._p.elements]..[i] = e,
    ),
  );

  CncPattern _with({
    String? name,
    String? milling,
    bool clearMilling = false,
    double? minW,
    double? minH,
    String? fallback,
    bool clearFallback = false,
    List<CncElement>? elements,
  }) => CncPattern(
    name: name ?? _p.name,
    milling: clearMilling ? null : milling ?? _p.milling,
    minW: minW ?? _p.minW,
    minH: minH ?? _p.minH,
    fallback: clearFallback ? null : fallback ?? _p.fallback,
    example: _p.example,
    elements: elements ?? _p.elements,
  );

  void _schedule({bool now = false}) {
    _timer?.cancel();
    if (now) {
      unawaited(_fetch());
    } else {
      _timer = Timer(widget.debounce, () => unawaited(_fetch()));
    }
  }

  Future<void> _fetch() async {
    final asked = ++_asked;
    setState(() => _loading = true);
    try {
      final got = await ref
          .read(cncPatternsRepositoryProvider)
          .preview(_p, width: _w, height: _h);
      if (!mounted || asked != _asked) return;
      setState(() {
        _preview = got;
        _error = null;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted || asked != _asked) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(cncPatternsRepositoryProvider)
          .savePattern(_p, oldName: widget.pattern?.name);
      ref.invalidate(cncStatusProvider);
      messenger.showDone(l10n.cncpPatternSaved(_p.name));
      navigator.pop(true);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = widget.pattern!.name;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cncpPatternDeleteAsk(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey('cncPatternDeleteYes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cncpDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(cncPatternsRepositoryProvider).deletePattern(name);
      ref.invalidate(cncStatusProvider);
      navigator.pop(true);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = _preview?.files ?? const <CncFile>[];
    if (files.isEmpty) return;
    final ext = _preview!.ext;
    final base =
        '${_p.name.isEmpty ? 'pattern' : _p.name}'
        '-${cncFmt(_h)}x${cncFmt(_w)}';
    final saver = ref.read(cncFileSaverProvider);
    try {
      final dir = await saver.save(l10n.cncpTrialsFolder, {
        for (final (i, f) in files.indexed)
          files.length > 1 ? '$base-${i + 1}-${f.tool}.$ext' : '$base.$ext':
              f.text,
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.cncpSavedTo(dir)),
          action: SnackBarAction(
            label: l10n.cncpOpenFolder,
            onPressed: () => unawaited(saver.open(dir)),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = _form(context, l10n);
    final preview = _previewPane(context, l10n);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pattern == null ? l10n.cncpPatternNew : widget.pattern!.name,
        ),
        actions: [
          if (_manage && widget.pattern != null)
            IconButton(
              key: const ValueKey('cncPatternDelete'),
              tooltip: l10n.cncpDelete,
              icon: const Icon(AppIcons.delete),
              onPressed: _busy ? null : () => unawaited(_delete()),
            ),
          if (_manage)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('cncPatternSave'),
                onPressed: _busy || _p.name.trim().isEmpty
                    ? null
                    : () => unawaited(_save()),
                child: Text(l10n.cncpSave),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: editor),
                  Expanded(flex: 4, child: preview),
                ],
              )
            : ListView(
                children: [
                  editor,
                  SizedBox(height: AppSpacing.xxxl * 8, child: preview),
                ],
              ),
      ),
    );
  }

  Widget _form(BuildContext context, AppLocalizations l10n) {
    final others = [
      for (final p in widget.status.patterns)
        if (p.name != widget.pattern?.name) p.name,
    ];
    final millings = {...widget.status.millings, ?_p.milling}.toList();
    final fields = <Widget>[
      TextFormField(
        key: const ValueKey('cncPatternName'),
        initialValue: _p.name,
        enabled: _manage,
        decoration: InputDecoration(labelText: l10n.cncpPatternName),
        onChanged: (v) => setState(() => _p = _with(name: v.trim())),
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String>(
        key: const ValueKey('cncPatternMilling'),
        initialValue: _p.milling ?? '',
        decoration: InputDecoration(
          labelText: l10n.cncpPatternMilling,
          helperText: l10n.cncpPatternMillingHint,
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(l10n.cncpNone)),
          for (final m in millings) DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: _manage
            ? (v) => _edit(
                (v ?? '').isEmpty
                    ? _with(clearMilling: true)
                    : _with(milling: v),
              )
            : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _NumField(
              keyName: 'cncPatternMinW',
              label: l10n.cncpPatternMinW,
              value: _p.minW,
              enabled: _manage,
              onChanged: (v) => _edit(_with(minW: v)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _NumField(
              keyName: 'cncPatternMinH',
              label: l10n.cncpPatternMinH,
              value: _p.minH,
              enabled: _manage,
              onChanged: (v) => _edit(_with(minH: v)),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String>(
        key: const ValueKey('cncPatternFallback'),
        initialValue: others.contains(_p.fallback) ? _p.fallback : '',
        decoration: InputDecoration(
          labelText: l10n.cncpPatternFallback,
          helperText: l10n.cncpPatternFallbackHint,
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(l10n.cncpNone)),
          for (final o in others) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: _manage
            ? (v) => setState(
                () => _p = (v ?? '').isEmpty
                    ? _with(clearFallback: true)
                    : _with(fallback: v),
              )
            : null,
      ),
      const SizedBox(height: AppSpacing.lg),
      SectionLabel(l10n.cncpElements),
      for (final (i, e) in _p.elements.indexed)
        _ElementCard(
          key: ValueKey('cncElement:$i:${e.kind.wire}'),
          index: i,
          element: e,
          tools: widget.status.tools,
          enabled: _manage,
          onChanged: (n) => _element(i, n),
          onRemove: _p.elements.length > 1
              ? () => _edit(_with(elements: [..._p.elements]..removeAt(i)))
              : null,
        ),
      if (_manage && _p.elements.length < 6)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('cncElementAdd'),
            onPressed: () => _edit(
              _with(
                elements: [
                  ..._p.elements,
                  CncElement(
                    kind: CncElementKind.grooves,
                    tool: widget.status.tools.firstOrNull?.name ?? '',
                  ),
                ],
              ),
            ),
            icon: const Icon(AppIcons.add),
            label: Text(l10n.cncpElementAdd),
          ),
        ),
    ];
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: fields,
    );
  }

  Widget _previewPane(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final p = _preview;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Height first, as every size here is said (owner, 19.11.2026).
              Expanded(
                child: _NumField(
                  keyName: 'cncTryH',
                  label: l10n.cncpTryHeight,
                  value: _h,
                  onChanged: (v) {
                    if (v < 50) return;
                    setState(() => _h = v);
                    _schedule();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NumField(
                  keyName: 'cncTryW',
                  label: l10n.cncpTryWidth,
                  value: _w,
                  onChanged: (v) {
                    if (v < 50) return;
                    setState(() => _w = v);
                    _schedule();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: CncFacadeView(
              key: const ValueKey('cncFacade'),
              width: _w,
              height: _h,
              cuts: p?.error == null ? p?.cuts ?? const [] : const [],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              l10n.cncpPreviewFailed,
              style: TextStyle(color: status.danger),
            ),
          if (p?.error != null)
            Text(
              p!.error!,
              key: const ValueKey('cncPreviewError'),
              style: TextStyle(color: status.danger),
            ),
          if (p != null && p.error == null) ...[
            if (p.example)
              Text(
                l10n.cncpExampleWarning,
                style: TextStyle(color: status.warning),
              ),
            for (final w in p.warnings)
              Text(w, style: TextStyle(color: status.warning)),
            Text(
              l10n.cncpPreviewStats(cncFmt(p.minutes), '${p.files.length}'),
              key: const ValueKey('cncPreviewStats'),
              style: theme.textTheme.titleSmall,
            ),
            for (final f in p.files)
              Text(
                l10n.cncpFileLine(
                  f.tool ?? '',
                  cncFmt(f.cutM),
                  '${f.passes}',
                  cncFmt(f.minutes),
                ),
                style: muted,
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('cncDownload'),
                onPressed: p.files.isEmpty
                    ? null
                    : () => unawaited(_download()),
                icon: const Icon(AppIcons.moveOut),
                label: Text(l10n.cncpDownload),
              ),
            ),
            Text(l10n.cncpCheckOnOffcut, style: muted),
          ],
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.helper,
  });

  final String keyName;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey(keyName),
    initialValue: cncFmt(value),
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      isDense: true,
    ),
    onChanged: (t) {
      final v = cncNumber(t);
      if (v != null) onChanged(v);
    },
  );
}

class _ElementCard extends StatelessWidget {
  const _ElementCard({
    required this.index,
    required this.element,
    required this.tools,
    required this.enabled,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final int index;
  final CncElement element;
  final List<CncTool> tools;
  final bool enabled;
  final ValueChanged<CncElement> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = element;
    final k = 'cncEl$index';
    Widget field(
      String key,
      String label,
      double value,
      CncElement Function(double) set, {
      String? helper,
    }) => _NumField(
      keyName: '$k:$key',
      label: label,
      value: value,
      enabled: enabled,
      helper: helper,
      onChanged: (v) => onChanged(set(v)),
    );
    final toolNames = [for (final t in tools) t.name];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<CncElementKind>(
                    key: ValueKey('$k:kind'),
                    segments: [
                      ButtonSegment(
                        value: CncElementKind.frame,
                        label: Text(l10n.cncpKindFrame),
                      ),
                      ButtonSegment(
                        value: CncElementKind.arch,
                        label: Text(l10n.cncpKindArch),
                      ),
                      ButtonSegment(
                        value: CncElementKind.grooves,
                        label: Text(l10n.cncpKindGrooves),
                      ),
                    ],
                    selected: {e.kind},
                    onSelectionChanged: enabled
                        ? (s) => onChanged(e.copyWith(kind: s.first))
                        : null,
                  ),
                ),
                if (enabled && onRemove != null)
                  IconButton(
                    key: ValueKey('$k:remove'),
                    tooltip: l10n.cncpDelete,
                    icon: const Icon(AppIcons.delete),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$k:tool'),
                    initialValue: toolNames.contains(e.tool) ? e.tool : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.cncpTool,
                      isDense: true,
                    ),
                    items: [
                      for (final t in toolNames)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: enabled
                        ? (v) => onChanged(e.copyWith(tool: v))
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: field(
                    'depth',
                    l10n.cncpDepth,
                    e.depth,
                    (v) => e.copyWith(depth: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...switch (e.kind) {
              CncElementKind.frame => [
                field(
                  'offset',
                  l10n.cncpOffset,
                  e.offset,
                  (v) => e.copyWith(offset: v),
                  helper: l10n.cncpOffsetHint,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<CncCorner>(
                  key: ValueKey('$k:corner'),
                  segments: [
                    ButtonSegment(
                      value: CncCorner.square,
                      label: Text(l10n.cncpCornerSquare),
                    ),
                    ButtonSegment(
                      value: CncCorner.round,
                      label: Text(l10n.cncpCornerRound),
                    ),
                    ButtonSegment(
                      value: CncCorner.cove,
                      label: Text(l10n.cncpCornerCove),
                    ),
                  ],
                  selected: {e.corner},
                  onSelectionChanged: enabled
                      ? (s) => onChanged(
                          e.copyWith(
                            corner: s.first,
                            radius: s.first != CncCorner.square && e.radius == 0
                                ? 15
                                : null,
                          ),
                        )
                      : null,
                ),
                if (e.corner != CncCorner.square) ...[
                  const SizedBox(height: AppSpacing.sm),
                  field(
                    'radius:${e.corner.wire}',
                    l10n.cncpRadius,
                    e.radius,
                    (v) => e.copyWith(radius: v),
                  ),
                ],
              ],
              CncElementKind.arch => [
                field(
                  'offset',
                  l10n.cncpOffset,
                  e.offset,
                  (v) => e.copyWith(offset: v),
                  helper: l10n.cncpOffsetHint,
                ),
                const SizedBox(height: AppSpacing.sm),
                field(
                  'rise',
                  l10n.cncpRise,
                  e.rise,
                  (v) => e.copyWith(rise: v),
                ),
              ],
              CncElementKind.grooves => [
                SegmentedButton<bool>(
                  key: ValueKey('$k:direction'),
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.cncpVertical),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.cncpHorizontal),
                    ),
                  ],
                  selected: {e.vertical},
                  onSelectionChanged: enabled
                      ? (s) => onChanged(e.copyWith(vertical: s.first))
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                field(
                  'step',
                  l10n.cncpStep,
                  e.step,
                  (v) => e.copyWith(step: v),
                ),
                const SizedBox(height: AppSpacing.sm),
                field(
                  'side',
                  l10n.cncpSide,
                  e.side,
                  (v) => e.copyWith(side: v),
                  helper: l10n.cncpSideHint,
                ),
                const SizedBox(height: AppSpacing.sm),
                field(
                  'ends',
                  l10n.cncpEnds,
                  e.ends,
                  (v) => e.copyWith(ends: v),
                  helper: l10n.cncpEndsHint,
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}
