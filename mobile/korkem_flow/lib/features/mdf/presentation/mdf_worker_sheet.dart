import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What the sheet answers. Empty — nobody named (ticking: the one it is
/// given to; assigning: the stage taken back); one — that person; several
/// — a crew, each with a share in %, or none said: equal (owner,
/// 26.11.2026: «2 или 3 вакуумщика делают вместе, и система делит»).
@immutable
class MdfCrewPick {
  const MdfCrewPick(this.members);

  final List<MdfCrewMember> members;

  /// The one person, when there is just one.
  String? get single => members.length == 1 ? members.single.employee : null;

  /// The crew, when there are several.
  List<MdfCrewMember>? get crew => members.length > 1 ? members : null;
}

/// «Кто сделал?» before a stage is ticked, or «Кому отдать?» when
/// [assigning] — one person or several, ticked; [areaM2] of the order is
/// what a crew splits. Null — the sheet was closed and nothing changes.
///
/// With [order] and [stage] the stage's own post comes first (owner,
/// 17.11.2026: the vacuum operator for the vacuum), then everyone else.
Future<MdfCrewPick?> pickMdfCrew(
  BuildContext context,
  String title, {
  String? order,
  MdfStage? stage,
  double? areaM2,
  List<MdfCrewPosition> positions = const [],
  List<String> given = const [],
  bool assigning = false,
}) => showModalBottomSheet<MdfCrewPick>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _WorkerSheet(
    title: title,
    order: order,
    stage: stage,
    areaM2: areaM2,
    positions: positions,
    given: given,
    assigning: assigning,
  ),
);

/// One position of the order, for «По позициям» (owner, 26.11.2026): who
/// made which — his m² are then the positions' own.
typedef MdfCrewPosition = ({String label, double m2});

/// The post a stage is done at, for a person added from the sheet — the
/// server's `team.STAGE_POSTS`; sanding goes to the PVC sander, the dialog
/// lets another be ticked.
const Map<MdfStage, String> mdfStagePost = {
  MdfStage.cut: 'cut.cutter',
  MdfStage.mill: 'cnc.operator',
  MdfStage.sand: 'pvc.sander',
  MdfStage.vacuum: 'pvc.vacuum',
  MdfStage.paint: 'paint.painter',
  MdfStage.ready: 'pack.packer',
};

class _WorkerSheet extends ConsumerStatefulWidget {
  const _WorkerSheet({
    required this.title,
    required this.order,
    required this.stage,
    required this.areaM2,
    required this.positions,
    required this.given,
    required this.assigning,
  });

  final String title;
  final String? order;
  final MdfStage? stage;
  final double? areaM2;
  final List<MdfCrewPosition> positions;
  final List<String> given;
  final bool assigning;

  @override
  ConsumerState<_WorkerSheet> createState() => _WorkerSheetState();
}

/// How a crew splits a stage.
enum _Split { equal, byHand, byPosition }

class _WorkerSheetState extends ConsumerState<_WorkerSheet> {
  /// Ticked, in the order they were ticked — the last takes the rest.
  late final List<String> _picked = [...widget.given];
  final _names = <String, String>{};
  final _parts = <String, TextEditingController>{};

  /// Fields of a crew since changed — still on screen this frame, so
  /// disposed with the sheet, not at once.
  final _old = <TextEditingController>[];
  _Split _mode = _Split.equal;

  /// «По позициям»: who made each position, by its index.
  final _madeBy = <int, String>{};

  @override
  void dispose() {
    for (final c in [..._parts.values, ..._old]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _area => widget.areaM2 ?? 0;

  /// m² when the order's area is known; % when it is not.
  bool get _inM2 => _area > 0;

  double get _whole => _inM2 ? _area : 100;

  /// One step of «−» / «+»: 0.1 m², or 1 %.
  double get _step => _inM2 ? 0.1 : 1;

  TextEditingController _part(String e) => _parts.putIfAbsent(
    e,
    () => TextEditingController(text: _num(_whole / _picked.length)),
  );

  double _value(String e) =>
      double.tryParse(_part(e).text.replaceAll(' ', '').replaceAll(',', '.')) ??
      0;

  double get _rest =>
      _whole -
      _picked.take(_picked.length - 1).fold<double>(0, (s, e) => s + _value(e));

  bool get _zero =>
      _picked.take(_picked.length - 1).any((e) => _value(e) <= 0);

  String _maker(int i) {
    final who = _madeBy[i];
    return who != null && _picked.contains(who)
        ? who
        : _picked[i % _picked.length];
  }

  /// Each one's part of the whole, in the order ticked.
  List<double> get _amounts => switch (_mode) {
    _Split.equal => [for (final _ in _picked) _whole / _picked.length],
    _Split.byHand => [
      for (final (i, e) in _picked.indexed)
        i == _picked.length - 1 ? _rest : _value(e),
    ],
    _Split.byPosition => [
      for (final e in _picked)
        widget.positions.indexed
            .where((p) => _maker(p.$1) == e)
            .fold<double>(0, (s, p) => s + p.$2.m2),
    ],
  };

  double get _positionsTotal =>
      widget.positions.fold<double>(0, (s, p) => s + p.m2);

  /// Someone ticked who made no position.
  String? get _idle {
    if (_mode != _Split.byPosition) return null;
    for (final (i, a) in _amounts.indexed) {
      if (a <= 0) return _names[_picked[i]] ?? _picked[i];
    }
    return null;
  }

  bool get _valid =>
      _picked.isNotEmpty &&
      (_picked.length < 2 ||
          switch (_mode) {
            _Split.equal => true,
            _Split.byHand => _rest > 0.001 && !_zero,
            _Split.byPosition => _idle == null && _positionsTotal > 0,
          });

  void _toggle(String e, String name) => setState(() {
    _names[e] = name;
    if (!_picked.remove(e)) _picked.add(e);
    // A new crew starts equal again: what was typed was for another one.
    _old.addAll(_parts.values);
    _parts.clear();
    if (_picked.length < 2) _mode = _Split.equal;
  });

  void _nudge(String e, double by) => setState(() {
    final next = (_value(e) + by).clamp(0, _whole).toDouble();
    _part(e).text = _num(next);
  });

  void _done() {
    final amounts = _amounts;
    final whole = _mode == _Split.byPosition ? _positionsTotal : _whole;
    final crew = [
      for (final (i, e) in _picked.indexed)
        MdfCrewMember(
          employee: e,
          name: _names[e] ?? e,
          share: _picked.length > 1 && _mode != _Split.equal
              ? amounts[i] * 100 / whole
              : null,
        ),
    ];
    Navigator.of(context).pop(MdfCrewPick(crew));
  }

  String _num(double v) {
    // Up to two decimals, no trailing zeros: 2, 1.4, 3.33.
    final text = ((v * 100).round() / 100)
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'en' ? text : text.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workers = ref.watch(mdfWorkersProvider);
    final key = widget.order != null && widget.stage != null
        ? (order: widget.order!, stage: widget.stage!)
        : null;
    final post = key == null
        ? const <MdfWorker>[]
        : ref.watch(mdfStagePeopleProvider(key)).value ?? const <MdfWorker>[];
    final nobody = widget.assigning
        ? (widget.given.isEmpty ? null : l10n.mdfStageTakeBack)
        : (widget.given.isEmpty ? l10n.mdfWorkerNobody : null);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget tile(MdfWorker w) {
      _names.putIfAbsent(w.employee, () => w.name);
      final at = _picked.indexOf(w.employee);
      return CheckboxListTile(
        key: ValueKey('worker:${w.employee}'),
        value: at >= 0,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(w.name),
        subtitle: w.role == null ? null : Text(w.role!),
        // His colour on the bar below, once a crew is split.
        secondary: at >= 0 && _picked.length > 1
            ? _Dot(color: AppColors.crewMember(at))
            : null,
        onChanged: (_) => _toggle(w.employee, w.name),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(widget.title, style: theme.textTheme.titleMedium),
              subtitle: Text(
                '${widget.assigning ? l10n.mdfGiveStageTo : l10n.mdfWhoDidIt}'
                ' ${l10n.mdfCrewHint}',
              ),
            ),
            if (nobody != null)
              ListTile(
                key: const ValueKey('workerNobody'),
                title: Text(nobody),
                onTap: () =>
                    Navigator.of(context).pop(const MdfCrewPick([])),
              ),
            const Divider(height: 1),
            Flexible(
              child: workers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(mdfWorkersProvider),
                ),
                data: (list) {
                  final everyone = {
                    for (final w in [...post, ...list]) w.employee: w,
                  };
                  // Who is ticked stands first, in the order ticked — the
                  // last of them takes the rest (owner, 26.11.2026).
                  final picked = [
                    for (final e in _picked)
                      everyone[e] ??
                          MdfWorker(employee: e, name: _names[e] ?? e),
                  ];
                  final ids = {for (final w in post) w.employee};
                  final ownPost = [
                    for (final w in post)
                      if (!_picked.contains(w.employee)) w,
                  ];
                  final others = [
                    for (final w in list)
                      if (!ids.contains(w.employee) &&
                          !_picked.contains(w.employee))
                        w,
                  ];
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (picked.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          title: SectionLabel(
                            l10n.mdfCrewPicked(picked.length),
                          ),
                        ),
                        for (final w in picked) tile(w),
                      ],
                      if (ownPost.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          title: SectionLabel(l10n.mdfStagePostPeople),
                        ),
                        for (final w in ownPost) tile(w),
                      ],
                      if (others.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          title: SectionLabel(l10n.mdfAllWorkers),
                        ),
                        for (final w in others) tile(w),
                      ],
                      if (list.isEmpty && post.isEmpty)
                        ListTile(
                          dense: true,
                          title: Text(l10n.mdfNoWorkers),
                        ),
                      // «+ Человек» (owner, 20.11.2026: «должен быть
                      // справочник, чтобы мы могли добавить людей») — into
                      // «Команда», on this stage's post; he is then picked.
                      ListTile(
                        key: const ValueKey('workerAdd'),
                        leading: const Icon(AppIcons.add),
                        title: Text(l10n.mdfAddWorker),
                        subtitle: Text(l10n.mdfAddWorkerHint),
                        onTap: () async {
                          final team = await ref.read(
                            teamPeopleProvider.future,
                          );
                          if (!context.mounted) return;
                          await showTeamPersonDialog(
                            context,
                            team,
                            post: widget.stage == null
                                ? null
                                : mdfStagePost[widget.stage],
                          );
                          ref.invalidate(mdfWorkersProvider);
                          if (key != null) {
                            ref.invalidate(mdfStagePeopleProvider(key));
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_picked.length > 1) ...[
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: _split(l10n, theme, muted),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('crewDone'),
                  onPressed: _valid ? _done : null,
                  child: Text(l10n.mdfCrewDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «Как поделить»: equal, by hand with the last taking the rest, or by
  /// the order's positions — and a bar of who has how much.
  Widget _split(AppLocalizations l10n, ThemeData theme, TextStyle? muted) {
    final unit = _inM2 ? 'м²' : '%';
    final amounts = _amounts;
    final whole = _mode == _Split.byPosition ? _positionsTotal : _whole;
    final rest = _rest;
    final over = _mode == _Split.byHand && rest <= 0.001;
    final idle = _idle;
    String pct(double v) => whole > 0 ? '${(v * 100 / whole).round()}%' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                _inM2
                    ? l10n.mdfCrewSplit(_num(_area))
                    : l10n.mdfCrewSplit('100%'),
                style: theme.textTheme.titleSmall,
              ),
              SegmentedButton<_Split>(
                key: const ValueKey('crewMode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Split.equal,
                    label: Text(l10n.mdfCrewEqual),
                  ),
                  ButtonSegment(
                    value: _Split.byHand,
                    label: Text(l10n.mdfCrewManual),
                  ),
                  if (widget.positions.isNotEmpty)
                    ButtonSegment(
                      value: _Split.byPosition,
                      label: Text(l10n.mdfCrewByPosition),
                    ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Bar(amounts: amounts),
          const SizedBox(height: AppSpacing.xs),
          if (_mode == _Split.equal)
            Text(
              l10n.mdfCrewEach(_picked.length, _num(_whole / _picked.length)),
              key: const ValueKey('crewEach'),
              style: muted?.copyWith(color: context.statusColors.success),
            )
          else if (_mode == _Split.byHand) ...[
            for (final (i, e) in _picked.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    _Dot(color: AppColors.crewMember(i)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        i == _picked.length - 1
                            ? '${_names[e] ?? e} · ${l10n.mdfCrewRest}'
                            : _names[e] ?? e,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i == _picked.length - 1)
                      Text(
                        '${_num(rest)} $unit',
                        key: const ValueKey('crewRest'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: over ? context.statusColors.danger : null,
                        ),
                      )
                    else ...[
                      IconButton(
                        key: ValueKey('crewLess:$e'),
                        tooltip: '−${_num(_step)}',
                        icon: const Icon(AppIcons.remove),
                        onPressed: () => _nudge(e, -_step),
                      ),
                      SizedBox(
                        width: AppSpacing.xxxl * 2,
                        child: TextField(
                          key: ValueKey('crewPart:$e'),
                          controller: _part(e),
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: unit,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('crewMore:$e'),
                        tooltip: '+${_num(_step)}',
                        icon: const Icon(AppIcons.add),
                        onPressed: () => _nudge(e, _step),
                      ),
                    ],
                    SizedBox(
                      width: AppSpacing.xxxl,
                      child: Text(
                        pct(amounts[i]),
                        textAlign: TextAlign.end,
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ),
            if (over || _zero)
              Text(
                over ? l10n.mdfCrewOver : l10n.mdfCrewZero,
                key: const ValueKey('crewError'),
                style: muted?.copyWith(color: context.statusColors.danger),
              ),
          ] else ...[
            // «По позициям»: who made each position; his m² are theirs.
            for (final (i, p) in widget.positions.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.label} · ${_num(p.m2)} м²',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownButton<String>(
                      key: ValueKey('crewPos:$i'),
                      value: _maker(i),
                      onChanged: (v) =>
                          setState(() => _madeBy[i] = v ?? _maker(i)),
                      items: [
                        for (final (j, e) in _picked.indexed)
                          DropdownMenuItem(
                            value: e,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Dot(color: AppColors.crewMember(j)),
                                const SizedBox(width: AppSpacing.xs),
                                Text(_names[e] ?? e),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final (i, e) in _picked.indexed)
                  Text(
                    '${_names[e] ?? e}: ${_num(amounts[i])} м² · '
                    '${pct(amounts[i])}',
                    key: ValueKey('crewGot:$e'),
                    style: muted,
                  ),
              ],
            ),
            if (idle != null)
              Text(
                l10n.mdfCrewIdle(idle),
                key: const ValueKey('crewError'),
                style: muted?.copyWith(color: context.statusColors.danger),
              ),
          ],
        ],
      ),
    );
  }
}

/// Who has how much, as one bar in each one's colour.
class _Bar extends StatelessWidget {
  const _Bar({required this.amounts});

  final List<double> amounts;

  @override
  Widget build(BuildContext context) {
    final parts = [for (final a in amounts) a > 0 ? a : 0.0];
    final total = parts.fold<double>(0, (s, a) => s + a);
    return ClipRRect(
      key: const ValueKey('crewBar'),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: SizedBox(
        height: AppSpacing.sm,
        child: total <= 0
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : Row(
                children: [
                  for (final (i, a) in parts.indexed)
                    if (a > 0)
                      Expanded(
                        flex: (a * 1000 / total).round().clamp(1, 1000),
                        child: ColoredBox(color: AppColors.crewMember(i)),
                      ),
                ],
              ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.sm,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
