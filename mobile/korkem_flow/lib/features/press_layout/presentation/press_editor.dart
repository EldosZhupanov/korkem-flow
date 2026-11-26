import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_edit.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_map.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A film's layout changed by hand: parts dragged over the table, turned,
/// moved to another load. True when something was kept.
Future<bool> showPressEditor(
  BuildContext context, {
  required String salesOrder,
  required FilmLayout film,
  required PressSettings press,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: PressEditor(salesOrder: salesOrder, film: film, press: press),
      ),
    ) ??
    false;

/// The editor: every load a table to scale; a part is pressed and dragged,
/// and let go it jumps onto the nearest line. A part that lies wrongly is
/// red, and while one is, the layout is not kept.
class PressEditor extends ConsumerStatefulWidget {
  const PressEditor({
    required this.salesOrder,
    required this.film,
    required this.press,
    super.key,
  });

  final String salesOrder;
  final FilmLayout film;
  final PressSettings press;

  @override
  ConsumerState<PressEditor> createState() => _PressEditorState();
}

class _PressEditorState extends ConsumerState<PressEditor> {
  late final List<List<PlacedPart>> _loads = [
    for (final load in widget.film.loads) [...load.placed],
  ];

  /// A longer section named for a load; null — the shortest that holds it.
  late final List<double?> _asked = [for (final _ in widget.film.loads) null];
  ({int load, int part})? _picked;
  bool _dragging = false;
  bool _busy = false;

  /// «Насильно» (owner, 26.11.2026): a part let go stays where it is —
  /// nearer than the gap, into the margin. On while Shift is held, or by
  /// the button on a touch screen.
  bool _force = false;

  bool get _forcing => _force || HardwareKeyboard.instance.isShiftPressed;

  PressSettings get _press => widget.press;

  PlacedPart? get _part =>
      _picked == null ? null : _loads[_picked!.load][_picked!.part];

  /// Some part lies nearer than the gap or in the margin — kept only with
  /// a reason.
  bool get _tight => _loads.any((l) => pressClashes(l, _press).isNotEmpty);

  bool get _valid {
    for (final (i, load) in _loads.indexed) {
      if (load.isEmpty) continue;
      if (pressOverlaps(load, _press).isNotEmpty) return false;
      if (!_force && pressClashes(load, _press).isNotEmpty) return false;
      if (pressSection(load, _press, asked: _asked[i]) == null) return false;
    }
    return _loads.any((l) => l.isNotEmpty);
  }

  double get _total {
    var sum = 0.0;
    for (final (i, load) in _loads.indexed) {
      if (load.isEmpty) continue;
      sum += pressSection(load, _press, asked: _asked[i])?.filmM ?? 0;
    }
    return sum;
  }

  void _turn() {
    final at = _picked;
    if (at == null || widget.film.textured) return;
    setState(() {
      final load = _loads[at.load];
      final others = [
        for (final (i, p) in load.indexed)
          if (i != at.part) p,
      ];
      load[at.part] = pressSnapped(pressTurned(load[at.part]), others, _press);
    });
  }

  void _moveTo(int target) {
    final at = _picked;
    if (at == null || target == at.load) return;
    setState(() {
      if (target == _loads.length) {
        _loads.add([]);
        _asked.add(null);
      }
      final part = _loads[at.load].removeAt(at.part);
      _loads[target].add(pressFreeSpot(part, _loads[target], _press));
      _picked = (load: target, part: _loads[target].length - 1);
    });
  }

  void _drag(int load, int part, Offset delta, double scale) {
    if (scale <= 0) return;
    setState(() {
      final p = _loads[load][part];
      _loads[load][part] = pressMoved(
        p,
        p.x + delta.dx / scale,
        p.y + delta.dy / scale,
      );
    });
  }

  void _drop(int load, int part) {
    if (_forcing) {
      // Where it was let go: the person knows why.
      setState(() {
        _dragging = false;
        _force = true;
      });
      return;
    }
    setState(() {
      _dragging = false;
      final others = [
        for (final (i, p) in _loads[load].indexed)
          if (i != part) p,
      ];
      _loads[load][part] = pressSnapped(_loads[load][part], others, _press);
    });
  }

  Future<void> _keep(List<PressLoad>? loads) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    String? forced;
    if (loads != null && _tight) {
      forced = await _askWhy(context);
      if (forced == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(pressLayoutRepositoryProvider)
          .saveLayout(
            widget.salesOrder,
            widget.film.decor,
            loads,
            forced: forced,
          );
      navigator.pop(true);
    } on Object catch (error) {
      if (mounted) setState(() => _busy = false);
      messenger.showFailure(error, l10n);
    }
  }

  /// Why the parts lie nearer than the gap — the journal keeps it.
  Future<String?> _askWhy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final why = TextEditingController();
    final said = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.pressForceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pressForceBody(_press.gapMm.round())),
              const SizedBox(height: AppSpacing.sm),
              ActionChip(
                key: const ValueKey('pressForce:usual'),
                label: Text(l10n.pressForceUsual),
                onPressed: () => setState(() => why.text = l10n.pressForceUsual),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('pressForce:why'),
                controller: why,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.pressForceWhy),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('pressForce:keep'),
              onPressed: why.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(why.text.trim()),
              child: Text(l10n.pressEditSave),
            ),
          ],
        ),
      ),
    );
    why.dispose();
    return said;
  }

  List<PressLoad> _result() => [
    for (final (i, load) in _loads.indexed)
      if (load.isNotEmpty)
        PressLoad(
          filmM: pressSection(load, _press, asked: _asked[i])?.filmM ?? 0,
          lengthMm: pressSection(load, _press, asked: _asked[i])?.lengthMm ?? 0,
          placed: load,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toLanguageTag(),
    );
    final part = _part;
    final valid = _valid;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pressEdit),
        actions: [
          TextButton.icon(
            key: const ValueKey('pressEdit:reset'),
            onPressed: _busy ? null : () => _keep(null),
            icon: const Icon(AppIcons.refresh, size: AppIconSize.dense),
            label: Text(l10n.pressEditReset),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            key: const ValueKey('pressEdit:save'),
            onPressed: valid && !_busy ? () => _keep(_result()) : null,
            child: Text(l10n.pressEditSave),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: ListView(
        physics: _dragging ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(widget.film.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.pressEditTotal(
              number.format(_total),
              number.format(widget.film.layoutM),
            ),
            key: const ValueKey('pressEdit:total'),
            style: theme.textTheme.titleMedium,
          ),
          if (!valid)
            Text(
              l10n.pressEditClash,
              key: const ValueKey('pressEdit:clash'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          // Shift, or this on a touch screen: a part stays where it is let
          // go — nearer than the gap, into the margin. Never on another
          // part or off the table.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              key: const ValueKey('pressEdit:force'),
              avatar: const Icon(AppIcons.force, size: AppIconSize.dense),
              label: Text(l10n.pressEditForce),
              tooltip: l10n.pressEditForceHint,
              selected: _force,
              onSelected: (on) => setState(() => _force = on),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (part == null)
            Text(
              l10n.pressEditHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.pressEditPart(
                    part.pos,
                    '${part.width.round()}×${part.height.round()}',
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                OutlinedButton(
                  key: const ValueKey('pressEdit:turn'),
                  onPressed: widget.film.textured ? null : _turn,
                  child: Text(
                    widget.film.textured
                        ? l10n.pressTextured
                        : l10n.pressEditRotate,
                  ),
                ),
                for (var i = 0; i < _loads.length; i++)
                  if (i != _picked!.load)
                    OutlinedButton(
                      key: ValueKey('pressEdit:to:$i'),
                      onPressed: () => _moveTo(i),
                      child: Text(l10n.pressEditMoveTo(i + 1)),
                    ),
                OutlinedButton.icon(
                  key: const ValueKey('pressEdit:toNew'),
                  onPressed: () => _moveTo(_loads.length),
                  icon: const Icon(AppIcons.add, size: AppIconSize.dense),
                  label: Text(l10n.pressEditMoveNew),
                ),
              ],
            ),
          for (final (i, load) in _loads.indexed) ...[
            const SizedBox(height: AppSpacing.lg),
            _head(context, i, load, number),
            const SizedBox(height: AppSpacing.xs),
            _table(context, i, load),
          ],
        ],
      ),
    );
  }

  Widget _head(
    BuildContext context,
    int i,
    List<PlacedPart> load,
    NumberFormat number,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final section = pressSection(load, _press, asked: _asked[i]);
    final least = pressSection(load, _press)?.lengthMm ?? double.infinity;
    final sections = [..._press.sections]
      ..sort((a, b) => a.lengthMm.compareTo(b.lengthMm));
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.pressLoad(i + 1, number.format(section?.filmM ?? 0)),
            key: ValueKey('pressEdit:load:$i'),
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (load.isNotEmpty)
          DropdownButton<double?>(
            key: ValueKey('pressEdit:section:$i'),
            value: _asked[i],
            isDense: true,
            onChanged: (value) => setState(() => _asked[i] = value),
            items: [
              DropdownMenuItem(child: Text(l10n.pressEditSectionAuto)),
              for (final s in sections)
                if (s.lengthMm > least || s.lengthMm == _asked[i])
                  DropdownMenuItem(
                    value: s.lengthMm,
                    child: Text(
                      l10n.pressEditSection(number.format(s.filmM)),
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _table(BuildContext context, int i, List<PlacedPart> load) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final longest = pressLongest(_press);
    final clashes = pressOverlaps(load, _press);
    final tight = pressClashes(load, _press).difference(clashes);
    final amber = context.statusColors.warning;
    final section = pressSection(load, _press, asked: _asked[i]);
    return LayoutBuilder(
      builder: (context, box) {
        final scale = longest > 0 ? box.maxWidth / longest : 0.0;
        return SizedBox(
          key: ValueKey('pressEdit:table:$i'),
          width: box.maxWidth,
          height: _press.widthMm * scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(color: scheme.outline),
                  ),
                ),
              ),
              // The film ends where its section does: the rest is bare.
              if (section != null && section.lengthMm < longest)
                Positioned(
                  left: section.lengthMm * scale,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: ColoredBox(
                    color: scheme.outline.withValues(alpha: AppTint.surface),
                  ),
                ),
              for (final (k, p) in load.indexed)
                Positioned(
                  left: p.x * scale,
                  top: p.y * scale,
                  width: p.width * scale,
                  height: p.height * scale,
                  child: Listener(
                    key: ValueKey('pressEdit:part:$i:$k'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => setState(() {
                      _picked = (load: i, part: k);
                      _dragging = true;
                    }),
                    onPointerMove: (e) => _drag(i, k, e.delta, scale),
                    onPointerUp: (_) => _drop(i, k),
                    onPointerCancel: (_) => _drop(i, k),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Each position its own colour, as on the map.
                        color: clashes.contains(k)
                            ? scheme.errorContainer
                            : PressMap.colourOf(
                                p.pos,
                              ).withValues(alpha: AppTint.pressPart),
                        border: Border.all(
                          color: clashes.contains(k)
                              ? scheme.error
                              : tight.contains(k)
                              ? (_force ? amber : scheme.error)
                              : PressMap.colourOf(p.pos),
                          width: _picked == (load: i, part: k)
                              ? AppStroke.focus * 2
                              : AppStroke.hairline,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${p.pos}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: clashes.contains(k)
                                  ? scheme.onErrorContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
