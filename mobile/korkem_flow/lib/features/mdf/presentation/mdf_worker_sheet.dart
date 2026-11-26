import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
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
    given: given,
    assigning: assigning,
  ),
);

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
    required this.given,
    required this.assigning,
  });

  final String title;
  final String? order;
  final MdfStage? stage;
  final double? areaM2;
  final List<String> given;
  final bool assigning;

  @override
  ConsumerState<_WorkerSheet> createState() => _WorkerSheetState();
}

class _WorkerSheetState extends ConsumerState<_WorkerSheet> {
  /// Ticked, in the order they were ticked — the last takes the rest.
  late final List<String> _picked = [...widget.given];
  final _names = <String, String>{};
  final _parts = <String, TextEditingController>{};

  /// Fields of a crew since changed — still on screen this frame, so
  /// disposed with the sheet, not at once.
  final _old = <TextEditingController>[];
  bool _byHand = false;

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

  bool get _zero => _picked.take(_picked.length - 1).any((e) => _value(e) <= 0);

  bool get _valid =>
      _picked.isNotEmpty &&
      (_picked.length < 2 || !_byHand || (_rest > 0.001 && !_zero));

  void _toggle(String e, String name) => setState(() {
    _names[e] = name;
    if (!_picked.remove(e)) _picked.add(e);
    // A new crew starts equal again: what was typed was for another one.
    _old.addAll(_parts.values);
    _parts.clear();
  });

  void _done() {
    final crew = [
      for (final (i, e) in _picked.indexed)
        MdfCrewMember(
          employee: e,
          name: _names[e] ?? e,
          share: _picked.length > 1 && _byHand
              ? (i == _picked.length - 1 ? _rest : _value(e)) * 100 / _whole
              : null,
        ),
    ];
    Navigator.of(context).pop(MdfCrewPick(crew));
  }

  String _num(double v) {
    final rounded = (v * 100).round() / 100;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
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
      return CheckboxListTile(
        key: ValueKey('worker:${w.employee}'),
        value: _picked.contains(w.employee),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(w.name),
        subtitle: w.role == null ? null : Text(w.role!),
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
                onTap: () => Navigator.of(context).pop(const MdfCrewPick([])),
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
                  final ids = {for (final w in post) w.employee};
                  final others = [
                    for (final w in list)
                      if (!ids.contains(w.employee)) w,
                  ];
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (post.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          title: SectionLabel(l10n.mdfStagePostPeople),
                        ),
                        for (final w in post) tile(w),
                        if (others.isNotEmpty)
                          ListTile(
                            dense: true,
                            title: SectionLabel(l10n.mdfAllWorkers),
                          ),
                      ],
                      for (final w in others) tile(w),
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
              _split(l10n, theme, muted),
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

  /// «Как поделить»: equal, or by hand with the last taking the rest.
  Widget _split(AppLocalizations l10n, ThemeData theme, TextStyle? muted) {
    final unit = _inM2 ? 'м²' : '%';
    final rest = _rest;
    final over = _byHand && rest <= 0.001;
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
              SegmentedButton<bool>(
                key: const ValueKey('crewMode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.mdfCrewEqual)),
                  ButtonSegment(value: true, label: Text(l10n.mdfCrewManual)),
                ],
                selected: {_byHand},
                onSelectionChanged: (v) => setState(() => _byHand = v.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!_byHand)
            Text(
              l10n.mdfCrewEach(_picked.length, _num(_whole / _picked.length)),
              key: const ValueKey('crewEach'),
              style: muted?.copyWith(color: context.statusColors.success),
            )
          else ...[
            for (final (i, e) in _picked.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
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
                    else
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
                  ],
                ),
              ),
            if (over || _zero)
              Text(
                over ? l10n.mdfCrewOver : l10n.mdfCrewZero,
                key: const ValueKey('crewError'),
                style: muted?.copyWith(color: context.statusColors.danger),
              ),
          ],
        ],
      ),
    );
  }
}
