import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/cnc_patterns/data/cnc_patterns_repository.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_pattern_editor.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Узоры ЧПУ (β)» (owner, 18.11.2026): facade patterns to G-code, in a
/// sandbox — off until the owner turns it on in this base, seen only by whom
/// they name, and never touching an order, the store or money.
class CncPatternsScreen extends ConsumerWidget {
  const CncPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(cncStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cncpTitle)),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(cncStatusProvider),
        ),
        data: (s) => s.visible ? _Library(status: s) : _Off(status: s),
      ),
    );
  }
}

Future<void> _act(
  BuildContext context,
  WidgetRef ref,
  Future<Object?> Function(CncPatternsRepository repo) call, {
  String? done,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await call(ref.read(cncPatternsRepositoryProvider));
    ref.invalidate(cncStatusProvider);
    if (done != null) messenger.showDone(done);
  } on Object catch (e) {
    messenger.showFailure(e, l10n);
  }
}

/// Off, or on but not for this person: what the module is and who turns it on.
class _Off extends ConsumerWidget {
  const _Off({required this.status});

  final CncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Card(
            key: const ValueKey('cncOff'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.cncpOffTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.cncpOffBody),
                  const SizedBox(height: AppSpacing.md),
                  if (status.enabled && !status.visible)
                    Text(l10n.cncpNotYours)
                  else if (status.canManage)
                    FilledButton.icon(
                      key: const ValueKey('cncEnable'),
                      onPressed: () => unawaited(
                        _act(
                          context,
                          ref,
                          (r) => r.setEnabled(enabled: true),
                          done: l10n.cncpEnabledDone,
                        ),
                      ),
                      icon: const Icon(AppIcons.check),
                      label: Text(l10n.cncpEnable),
                    )
                  else
                    Text(l10n.cncpOwnerTurnsOn),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Library extends StatelessWidget {
  const _Library({required this.status});

  final CncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warn = context.statusColors.warning;
    final tabs = [
      Tab(text: l10n.cncpTabPatterns),
      Tab(text: l10n.cncpTabTools),
      Tab(text: l10n.cncpTabMachine),
      if (status.canManage) Tab(text: l10n.cncpTabAccess),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                Icon(AppIcons.warning, color: warn),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.cncpBetaBanner,
                    key: const ValueKey('cncBeta'),
                    style: TextStyle(color: warn),
                  ),
                ),
              ],
            ),
          ),
          TabBar(tabs: tabs),
          Expanded(
            child: TabBarView(
              children: [
                _PatternsTab(status: status),
                _ToolsTab(status: status),
                _MachineTab(status: status),
                if (status.canManage) _AccessTab(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Рамка · вогнутый угол 15 · V-90° · 4 мм» — what an element is, in a line.
String cncElementLine(AppLocalizations l10n, CncElement e) {
  final shape = switch (e.kind) {
    CncElementKind.frame => switch (e.corner) {
      CncCorner.square => l10n.cncpLineFrame(cncFmt(e.offset)),
      CncCorner.round => l10n.cncpLineFrameRound(
        cncFmt(e.offset),
        cncFmt(e.radius),
      ),
      CncCorner.cove => l10n.cncpLineFrameCove(
        cncFmt(e.offset),
        cncFmt(e.radius),
      ),
    },
    CncElementKind.arch => l10n.cncpLineArch(cncFmt(e.offset), cncFmt(e.rise)),
    CncElementKind.grooves =>
      e.vertical
          ? l10n.cncpLineGroovesV(cncFmt(e.step))
          : l10n.cncpLineGroovesH(cncFmt(e.step)),
  };
  return l10n.cncpLineTool(shape, e.tool, cncFmt(e.depth));
}

class _PatternsTab extends StatelessWidget {
  const _PatternsTab({required this.status});

  final CncStatus status;

  Future<void> _open(BuildContext context, CncPattern? pattern) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CncPatternEditor(status: status, pattern: pattern),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.cncpPatternsHint, style: muted),
        const SizedBox(height: AppSpacing.sm),
        if (status.canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('cncPatternAdd'),
              onPressed: status.tools.isEmpty
                  ? null
                  : () => unawaited(_open(context, null)),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.cncpPatternNew),
            ),
          ),
        if (status.patterns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(l10n.cncpPatternsEmpty, style: muted),
          ),
        for (final p in status.patterns)
          Card(
            key: ValueKey('cncPattern:${p.name}'),
            child: ListTile(
              leading: const Icon(AppIcons.design),
              title: Text(
                p.example ? '${p.name} · ${l10n.cncpExample}' : p.name,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.milling == null
                        ? l10n.cncpNoMilling
                        : l10n.cncpForMilling(p.milling!),
                  ),
                  for (final e in p.elements)
                    Text(cncElementLine(l10n, e), style: muted),
                  if (p.minW > 0 || p.minH > 0)
                    Text(
                      p.fallback == null
                          ? l10n.cncpMinSize(cncFmt(p.minW), cncFmt(p.minH))
                          : l10n.cncpMinSizeFallback(
                              cncFmt(p.minW),
                              cncFmt(p.minH),
                              p.fallback!,
                            ),
                      style: muted,
                    ),
                ],
              ),
              onTap: () => unawaited(_open(context, p)),
            ),
          ),
      ],
    );
  }
}

class _ToolsTab extends ConsumerStatefulWidget {
  const _ToolsTab({required this.status});

  final CncStatus status;

  @override
  ConsumerState<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends ConsumerState<_ToolsTab> {
  String _query = '';

  /// A tool found by its name, its diameter or its angle: «90», «R3», «6».
  bool _found(CncTool t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      t.name,
      cncFmt(t.diameter),
      if (t.kind == CncToolKind.v) '${cncFmt(t.angle)}°',
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = widget.status;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final shown = [
      for (final t in status.tools)
        if (_found(t)) t,
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.cncpToolsHint, style: muted),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status.canManage) ...[
              FilledButton.icon(
                key: const ValueKey('cncToolAdd'),
                onPressed: () => unawaited(_editTool(context, ref, null)),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.cncpToolNew),
              ),
              // ArtCAM's own tool database (owner, 19.11.2026).
              OutlinedButton.icon(
                key: const ValueKey('cncToolArtcam'),
                onPressed: () => unawaited(_fromArtcam(context, ref)),
                icon: const Icon(AppIcons.attachment),
                label: Text(l10n.cncpArtcam),
              ),
            ],
            SizedBox(
              width: AppBreakpoints.listPaneWidth,
              child: TextField(
                key: const ValueKey('cncToolSearch'),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.cncpToolsSearch,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // By shape: V-shaped, radiused, straight — a long list stays read.
        for (final kind in CncToolKind.values)
          if (shown.any((t) => t.kind == kind)) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _kind(l10n, kind),
                style: theme.textTheme.labelMedium,
              ),
            ),
            for (final t in shown)
              if (t.kind == kind) _toolCard(context, t),
          ],
      ],
    );
  }

  Widget _toolCard(BuildContext context, CncTool t) {
    final l10n = AppLocalizations.of(context);
    final status = widget.status;
    return Card(
      key: ValueKey('cncTool:${t.name}'),
      child: ListTile(
        leading: const Icon(AppIcons.diameter),
        title: Text(t.name),
        subtitle: Text(
          l10n.cncpToolLine(
            _kind(l10n, t.kind),
            cncFmt(t.diameter),
            cncFmt(t.feed),
            cncFmt(t.rpm),
            cncFmt(t.passDepth),
          ),
        ),
        trailing: status.canManage
            ? IconButton(
                key: ValueKey('cncToolDelete:${t.name}'),
                tooltip: l10n.cncpDelete,
                icon: const Icon(AppIcons.delete),
                onPressed: () => unawaited(
                  _act(context, ref, (r) => r.deleteTool(t.name)),
                ),
              )
            : null,
        onTap: status.canManage
            ? () => unawaited(_editTool(context, ref, t))
            : null,
      ),
    );
  }

  Future<void> _fromArtcam(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final List<PickedFile> files;
    try {
      files = await ref
          .read(filmFilePickerProvider)
          .pick(extensions: const ['tdb']);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return;
    }
    if (files.isEmpty || !context.mounted) return;
    final file = files.first.bytes;
    final picked = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ArtcamDialog(
        tools: ref.read(cncPatternsRepositoryProvider).artcamPreview(file),
      ),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    await _act(
      context,
      ref,
      (r) => r.artcamAdd(file, picked),
      done: l10n.cncpArtcamAdded(picked.length),
    );
  }

  Future<void> _editTool(
    BuildContext context,
    WidgetRef ref,
    CncTool? tool,
  ) async {
    final edited = await showDialog<CncTool>(
      context: context,
      builder: (_) => _ToolDialog(tool: tool),
    );
    if (edited == null || !context.mounted) return;
    await _act(context, ref, (r) => r.saveTool(edited, oldName: tool?.name));
  }
}

String _kind(AppLocalizations l10n, CncToolKind k) => switch (k) {
  CncToolKind.v => l10n.cncpToolV,
  CncToolKind.ball => l10n.cncpToolBall,
  CncToolKind.flat => l10n.cncpToolFlat,
};

class _ToolDialog extends StatefulWidget {
  const _ToolDialog({this.tool});

  final CncTool? tool;

  @override
  State<_ToolDialog> createState() => _ToolDialogState();
}

class _ToolDialogState extends State<_ToolDialog> {
  late CncTool _t = widget.tool ?? const CncTool(name: '');

  CncTool _with({
    String? name,
    CncToolKind? kind,
    double? diameter,
    double? angle,
    double? feed,
    double? plunge,
    double? rpm,
    double? passDepth,
  }) => CncTool(
    name: name ?? _t.name,
    kind: kind ?? _t.kind,
    diameter: diameter ?? _t.diameter,
    angle: angle ?? _t.angle,
    feed: feed ?? _t.feed,
    plunge: plunge ?? _t.plunge,
    rpm: rpm ?? _t.rpm,
    passDepth: passDepth ?? _t.passDepth,
  );

  Widget _num(
    String key,
    String label,
    double value,
    CncTool Function(double) set,
  ) => TextFormField(
    key: ValueKey('cncToolField:$key'),
    initialValue: cncFmt(value),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (t) {
      final v = cncNumber(t);
      if (v != null) setState(() => _t = set(v));
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.tool == null ? l10n.cncpToolNew : widget.tool!.name),
      content: SizedBox(
        width: AppSpacing.xxxl * 12,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('cncToolName'),
                initialValue: _t.name,
                decoration: InputDecoration(labelText: l10n.cncpToolName),
                onChanged: (v) => setState(() => _t = _with(name: v.trim())),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<CncToolKind>(
                key: const ValueKey('cncToolKind'),
                segments: [
                  for (final k in CncToolKind.values)
                    ButtonSegment(value: k, label: Text(_kind(l10n, k))),
                ],
                selected: {_t.kind},
                onSelectionChanged: (s) =>
                    setState(() => _t = _with(kind: s.first)),
              ),
              const SizedBox(height: AppSpacing.sm),
              _num(
                'diameter',
                l10n.cncpDiameter,
                _t.diameter,
                (v) => _with(diameter: v),
              ),
              if (_t.kind == CncToolKind.v)
                _num('angle', l10n.cncpAngle, _t.angle, (v) => _with(angle: v)),
              _num('feed', l10n.cncpFeed, _t.feed, (v) => _with(feed: v)),
              _num(
                'plunge',
                l10n.cncpPlunge,
                _t.plunge,
                (v) => _with(plunge: v),
              ),
              _num('rpm', l10n.cncpRpm, _t.rpm, (v) => _with(rpm: v)),
              _num(
                'pass',
                l10n.cncpPassDepth,
                _t.passDepth,
                (v) => _with(passDepth: v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cncToolSave'),
          onPressed: _t.name.isEmpty ? null : () => Navigator.pop(context, _t),
          child: Text(l10n.cncpSave),
        ),
      ],
    );
  }
}

class _MachineTab extends ConsumerStatefulWidget {
  const _MachineTab({required this.status});

  final CncStatus status;

  @override
  ConsumerState<_MachineTab> createState() => _MachineTabState();
}

class _MachineTabState extends ConsumerState<_MachineTab> {
  late CncMachine _m = widget.status.machine;

  CncMachine _with({
    String? ext,
    bool? comments,
    bool? arcs,
    bool? lineNumbers,
    bool? swapXy,
    double? safeZ,
    double? clearZ,
    double? rapid,
    double? dwell,
  }) => CncMachine(
    ext: ext ?? _m.ext,
    comments: comments ?? _m.comments,
    arcs: arcs ?? _m.arcs,
    lineNumbers: lineNumbers ?? _m.lineNumbers,
    swapXy: swapXy ?? _m.swapXy,
    safeZ: safeZ ?? _m.safeZ,
    clearZ: clearZ ?? _m.clearZ,
    rapid: rapid ?? _m.rapid,
    dwell: dwell ?? _m.dwell,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manage = widget.status.canManage;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget number(
      String key,
      String label,
      double value,
      CncMachine Function(double) set,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        key: ValueKey('cncMachine:$key'),
        initialValue: cncFmt(value),
        enabled: manage,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (t) {
          final v = cncNumber(t);
          if (v != null) setState(() => _m = set(v));
        },
      ),
    );
    Widget flag(
      String key,
      String label,
      CncMachine Function({required bool on}) set, {
      required bool value,
    }) => SwitchListTile(
      key: ValueKey('cncMachine:$key'),
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: manage ? (v) => setState(() => _m = set(on: v)) : null,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.cncpMachineHint, style: muted),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey('cncMachine:ext'),
                initialValue: _m.ext,
                decoration: InputDecoration(labelText: l10n.cncpExt),
                items: [
                  for (final e in const ['nc', 'tap', 'gcode', 'txt', 'cnc'])
                    DropdownMenuItem(value: e, child: Text('.$e')),
                ],
                onChanged: manage
                    ? (v) => setState(() => _m = _with(ext: v))
                    : null,
              ),
              flag(
                'arcs',
                l10n.cncpArcs,
                ({required on}) => _with(arcs: on),
                value: _m.arcs,
              ),
              flag(
                'comments',
                l10n.cncpComments,
                ({required on}) => _with(comments: on),
                value: _m.comments,
              ),
              flag(
                'lines',
                l10n.cncpLineNumbers,
                ({required on}) => _with(lineNumbers: on),
                value: _m.lineNumbers,
              ),
              flag(
                'swap',
                l10n.cncpSwapXy,
                ({required on}) => _with(swapXy: on),
                value: _m.swapXy,
              ),
              const SizedBox(height: AppSpacing.sm),
              number('safe', l10n.cncpSafeZ, _m.safeZ, (v) => _with(safeZ: v)),
              number(
                'clear',
                l10n.cncpClearZ,
                _m.clearZ,
                (v) => _with(clearZ: v),
              ),
              number('rapid', l10n.cncpRapid, _m.rapid, (v) => _with(rapid: v)),
              number('dwell', l10n.cncpDwell, _m.dwell, (v) => _with(dwell: v)),
              Text(l10n.cncpOriginNote, style: muted),
              if (manage) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: const ValueKey('cncMachineSave'),
                    onPressed: () => unawaited(
                      _act(
                        context,
                        ref,
                        (r) => r.setMachine(_m),
                        done: l10n.cncpMachineSaved,
                      ),
                    ),
                    child: Text(l10n.cncpSave),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessTab extends ConsumerStatefulWidget {
  const _AccessTab({required this.status});

  final CncStatus status;

  @override
  ConsumerState<_AccessTab> createState() => _AccessTabState();
}

class _AccessTabState extends ConsumerState<_AccessTab> {
  late final Set<String> _users = {...widget.status.users};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.cncpAccessHint, style: muted),
              const SizedBox(height: AppSpacing.sm),
              for (final p in widget.status.people)
                CheckboxListTile(
                  key: ValueKey('cncUser:${p.user}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text(p.user),
                  value: _users.contains(p.user),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _users.add(p.user);
                    } else {
                      _users.remove(p.user);
                    }
                  }),
                ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    key: const ValueKey('cncAccessSave'),
                    onPressed: () => unawaited(
                      _act(
                        context,
                        ref,
                        (r) => r.setEnabled(
                          enabled: true,
                          users: _users.toList(),
                        ),
                        done: l10n.cncpAccessSaved,
                      ),
                    ),
                    child: Text(l10n.cncpSave),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('cncDisable'),
                    onPressed: () => unawaited(
                      _act(
                        context,
                        ref,
                        (r) => r.setEnabled(enabled: false),
                        done: l10n.cncpDisabledDone,
                      ),
                    ),
                    icon: const Icon(AppIcons.hidden),
                    label: Text(l10n.cncpDisable),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tools of an ArtCAM tool database, by its groups (owner, 19.11.2026):
/// the wood and MDF ones ticked; one that cannot be cut by our patterns, or
/// whose speeds no machine runs, shown with why and not to be ticked. Gives
/// the ticked ones' places in the file.
class _ArtcamDialog extends StatefulWidget {
  const _ArtcamDialog({required this.tools});

  final Future<List<ArtcamTool>> tools;

  @override
  State<_ArtcamDialog> createState() => _ArtcamDialogState();
}

class _ArtcamDialogState extends State<_ArtcamDialog> {
  List<ArtcamTool>? _all;
  Object? _error;
  Set<int> _picked = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final all = await widget.tools;
      if (!mounted) return;
      setState(() {
        _all = all;
        _picked = {
          for (final t in all)
            if (t.ready && _wood(t)) t.index,
        };
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  static bool _wood(ArtcamTool t) {
    final g = t.group.toLowerCase();
    return g.contains('wood') || g.contains('дерев') || g.contains('мдф');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      key: const ValueKey('cncArtcam'),
      title: Text(l10n.cncpArtcamTitle),
      content: SizedBox(
        width: math.min(AppSpacing.xxxl * 15, screen.width * 0.8),
        height: math.min(AppSpacing.xxxl * 14, screen.height * 0.65),
        child: Builder(
          builder: (context) {
            if (_error != null) return ErrorView(error: _error!);
            final all = _all;
            if (all == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final picked = _picked;
            final q = _query.trim().toLowerCase();
            final shown = [
              for (final t in all)
                if (q.isEmpty ||
                    '${t.group} ${t.name}'.toLowerCase().contains(q))
                  t,
            ];
            final groups = <String, List<ArtcamTool>>{};
            for (final t in shown) {
              groups.putIfAbsent(t.group, () => []).add(t);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.cncpArtcamHint(
                    all.length,
                    all.where((t) => t.ready).length,
                  ),
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('cncArtcamSearch'),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.cncpToolsSearch,
                    isDense: true,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in groups.entries) ...[
                        CheckboxListTile(
                          key: ValueKey('cncArtcamGroup:${e.key}'),
                          dense: true,
                          tristate: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            e.key,
                            style: theme.textTheme.labelLarge,
                          ),
                          value: () {
                            final ready = [
                              for (final t in e.value)
                                if (t.ready) t.index,
                            ];
                            if (ready.isEmpty) return false;
                            final on = ready.where(picked.contains).length;
                            return on == 0
                                ? false
                                : on == ready.length
                                ? true
                                : null;
                          }(),
                          onChanged: e.value.any((t) => t.ready)
                              ? (on) => setState(() {
                                  for (final t in e.value) {
                                    if (!t.ready) continue;
                                    if (on ?? false) {
                                      picked.add(t.index);
                                    } else {
                                      picked.remove(t.index);
                                    }
                                  }
                                })
                              : null,
                        ),
                        for (final t in e.value)
                          CheckboxListTile(
                            key: ValueKey('cncArtcamTool:${t.index}'),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: AppSpacing.xl,
                            ),
                            value: picked.contains(t.index),
                            onChanged: t.ready
                                ? (on) => setState(
                                    () => (on ?? false)
                                        ? picked.add(t.index)
                                        : picked.remove(t.index),
                                  )
                                : null,
                            title: Text(t.name),
                            subtitle: Text(
                              t.why ??
                                  l10n.cncpToolLine(
                                    _kind(l10n, t.kind!),
                                    cncFmt(t.diameter),
                                    cncFmt(t.feed),
                                    cncFmt(t.rpm),
                                    cncFmt(t.passDepth),
                                  ),
                              style: muted,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cncArtcamAdd'),
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.of(context).pop(_picked.toList()),
          child: Text(l10n.cncpArtcamAdd(_picked.length)),
        ),
      ],
    );
  }
}
