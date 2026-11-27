import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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

/// Where a dragged part is let go, other than its own table: another
/// load's table, the tray — or nowhere, and it goes back.
const int _tray = -1;

/// The loads, the sections asked for them and the tray, at one moment —
/// what «Отменить» goes back to.
typedef _State = ({
  List<List<PlacedPart>> loads,
  List<double?> asked,
  List<PlacedPart> tray,
});

/// How far back «Отменить» reaches.
const int _history = 50;

/// The scale's steps and bounds, against the table fitted to the screen.
const double _zoomStep = 1.25;
const double _zoomMin = 0.5;
const double _zoomMax = 4;

/// A table is never taller than this at 100 % (owner, 27.11.2026: «не прям
/// таким большим») — the whole of it, with the next one, on the screen.
const double _tableMax = AppSpacing.xxxl * 7;

/// The ruler's step along the table, mm.
const double _rulerMm = 500;

/// The editor (owner, 12.11.2026, grown 27.11.2026): every load a table to
/// scale, with a ruler; a part is pressed and dragged — onto another load,
/// or into the tray — and let go it jumps onto the nearest line, the
/// millimetres to its neighbours shown. A part that lies wrongly is red,
/// and while one is, the layout is not kept. Ctrl+Z, arrows, R, Delete.
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
  late List<List<PlacedPart>> _loads = [
    for (final load in widget.film.loads) [...load.placed],
  ];

  /// A longer section named for a load; null — the shortest that holds it.
  late List<double?> _asked = [for (final _ in widget.film.loads) null];

  /// Parts put aside to make room (owner, 27.11.2026): never kept so — laid
  /// by hand or by «Доуложить сам» before the layout is saved.
  List<PlacedPart> _waiting = [];

  final List<_State> _undo = [];
  final List<_State> _redo = [];

  /// The part picked: a load's, or the tray's ([_tray]).
  ({int load, int part})? _picked;
  bool _dragging = false;
  bool _busy = false;

  /// Where in the dragged part it was taken, mm from its corner.
  Offset _grab = Offset.zero;

  /// The pointer, while a part is carried off its own table.
  Offset? _carried;

  /// The layout as it was when a drag began: a drag let go nowhere goes
  /// back to it, and «Отменить» undoes the whole drag at once.
  _State? _before;

  double _zoom = 1;

  /// Pixels a millimetre, as last laid out — the same for every table.
  double _scale = 0;

  final List<GlobalKey> _tables = [];
  final GlobalKey _trayKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final FocusNode _focus = FocusNode();
  final FocusNode _xFocus = FocusNode();
  final FocusNode _yFocus = FocusNode();

  /// «Насильно» (owner, 26.11.2026): a part let go stays where it is —
  /// nearer than the gap, into the margin. On while Shift is held, or by
  /// the button on a touch screen.
  bool _force = false;

  bool get _forcing => _force || HardwareKeyboard.instance.isShiftPressed;

  PressSettings get _press => widget.press;

  /// A part may be turned by hand: not on a textured film.
  bool get _turnable => !widget.film.textured;

  @override
  void dispose() {
    _focus.dispose();
    _xFocus.dispose();
    _yFocus.dispose();
    super.dispose();
  }

  PlacedPart? get _part {
    final at = _picked;
    if (at == null) return null;
    if (at.load == _tray) {
      return at.part < _waiting.length ? _waiting[at.part] : null;
    }
    if (at.load >= _loads.length || at.part >= _loads[at.load].length) {
      return null;
    }
    return _loads[at.load][at.part];
  }

  GlobalKey _tableKey(int i) {
    while (_tables.length <= i) {
      _tables.add(GlobalKey());
    }
    return _tables[i];
  }

  _State _now() => (
    loads: [
      for (final l in _loads) [...l],
    ],
    asked: [..._asked],
    tray: [..._waiting],
  );

  void _restore(_State s) {
    _loads = [
      for (final l in s.loads) [...l],
    ];
    _asked = [...s.asked];
    _waiting = [...s.tray];
    _picked = null;
  }

  void _remember([_State? state]) {
    _undo.add(state ?? _now());
    if (_undo.length > _history) _undo.removeAt(0);
    _redo.clear();
  }

  /// A change «Отменить» can take back.
  void _change(VoidCallback change) => setState(() {
    _remember();
    change();
  });

  void _back() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_now());
      _restore(_undo.removeLast());
    });
  }

  void _forward() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_now());
      _restore(_redo.removeLast());
    });
  }

  void _zoomBy(double factor) => setState(
    () => _zoom = (_zoom * factor).clamp(_zoomMin, _zoomMax),
  );

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

  List<PlacedPart> _othersOf(int load, int part) => [
    for (final (i, p) in _loads[load].indexed)
      if (i != part) p,
  ];

  void _turn() {
    final at = _picked;
    if (at == null || at.load == _tray || !_turnable) return;
    _change(() {
      _loads[at.load][at.part] = pressSnapped(
        pressTurned(_loads[at.load][at.part]),
        _othersOf(at.load, at.part),
        _press,
      );
    });
  }

  /// Across the table's middle (owner, 27.11.2026: «по центру»).
  void _centre() {
    final at = _picked;
    if (at == null || at.load == _tray) return;
    final p = _loads[at.load][at.part];
    _change(() {
      _loads[at.load][at.part] = pressMoved(
        p,
        p.x,
        ((_press.widthMm - p.height) / 2).roundToDouble(),
      );
    });
  }

  /// To another load's first free place, a new load, or the tray.
  void _moveTo(int target) {
    final at = _picked;
    if (at == null || target == at.load) return;
    _change(() {
      final part = at.load == _tray
          ? _waiting.removeAt(at.part)
          : _loads[at.load].removeAt(at.part);
      if (target == _tray) {
        _waiting.add(part);
        _picked = (load: _tray, part: _waiting.length - 1);
        return;
      }
      if (target == _loads.length) {
        _loads.add([]);
        _asked.add(null);
      }
      _loads[target].add(pressFreeSpot(part, _loads[target], _press));
      _picked = (load: target, part: _loads[target].length - 1);
    });
  }

  /// A clean table to drag parts onto (owner, 27.11.2026).
  void _addEmpty() => _change(() {
    _loads.add([]);
    _asked.add(null);
  });

  void _dropEmpty(int i) => _change(() {
    _loads.removeAt(i);
    _asked.removeAt(i);
    if (_tables.length > i) _tables.removeAt(i);
    _picked = null;
  });

  /// «Доуложить сам»: every part in the tray to the first load with room
  /// for it, a new load when none has.
  void _layRest() {
    if (_waiting.isEmpty) return;
    final turn = _turnable && !widget.film.unchecked && !widget.film.textured;
    _change(() {
      for (final p in [..._waiting]) {
        final spot = pressPlaceAnywhere(p, _loads, _press, turn: turn);
        if (spot != null) {
          _loads[spot.load].add(spot.part);
        } else {
          _loads.add([pressFreeSpot(p, const [], _press)]);
          _asked.add(null);
        }
      }
      _waiting = [];
      _picked = null;
    });
  }

  /// A part picked from a table and pressed: a drag may follow.
  void _pressPart(int load, int part, PointerDownEvent e, double scale) {
    _focus.requestFocus();
    setState(() {
      _picked = (load: load, part: part);
      _dragging = true;
      _before = _now();
      _carried = null;
      _grab = scale > 0 ? e.localPosition / scale : Offset.zero;
    });
  }

  /// A part taken from the tray: carried with the pointer by its middle.
  void _pressTray(int part) {
    _focus.requestFocus();
    final p = _waiting[part];
    setState(() {
      _picked = (load: _tray, part: part);
      _dragging = true;
      _before = _now();
      _carried = null;
      _grab = Offset(p.width / 2, p.height / 2);
    });
  }

  void _drag(int load, int part, PointerMoveEvent e, double scale) {
    if (scale <= 0) return;
    setState(() {
      if (load != _tray) {
        final p = _loads[load][part];
        _loads[load][part] = pressMoved(
          p,
          p.x + e.delta.dx / scale,
          p.y + e.delta.dy / scale,
        );
      }
      // Off its own table it is carried as a shadow over the screen.
      _carried = _targetAt(e.position) == load ? null : e.position;
    });
  }

  /// The table — or the tray — under a point of the screen.
  int? _targetAt(Offset global) {
    bool under(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return false;
      return (box.localToGlobal(Offset.zero) & box.size).contains(global);
    }

    for (var i = 0; i < _loads.length && i < _tables.length; i++) {
      if (under(_tables[i])) return i;
    }
    if (under(_trayKey)) return _tray;
    return null;
  }

  void _drop(int load, int part, Offset global) {
    final before = _before;
    final target = _targetAt(global);
    setState(() {
      _dragging = false;
      _carried = null;
      _before = null;
    });
    if (target == null) {
      // Let go over nothing: back where it was.
      if (before != null && load != _tray) setState(() => _restore(before));
      return;
    }
    if (target == load) {
      if (load == _tray) return;
      setState(() {
        _remember(before);
        if (!_forcing) {
          _loads[load][part] = pressSnapped(
            _loads[load][part],
            _othersOf(load, part),
            _press,
          );
        } else {
          // Where it was let go: the person knows why.
          _force = true;
        }
      });
      return;
    }
    setState(() {
      _remember(before);
      final original = load == _tray
          ? _waiting.removeAt(part)
          : (before?.loads[load][part] ?? _loads[load][part]);
      if (load != _tray) _loads[load].removeAt(part);
      if (target == _tray) {
        _waiting.add(original);
        _picked = (load: _tray, part: _waiting.length - 1);
        return;
      }
      _loads[target].add(_landed(original, target, global));
      _picked = (load: target, part: _loads[target].length - 1);
    });
  }

  /// Where a part carried onto another table lands: under the pointer, on
  /// the nearest line — or the first free place, when that one is taken.
  PlacedPart _landed(PlacedPart part, int target, Offset global) {
    final box = _tables[target].currentContext?.findRenderObject();
    final others = _loads[target];
    if (box is! RenderBox || _scale <= 0) {
      return pressFreeSpot(part, others, _press);
    }
    final local = box.globalToLocal(global) / _scale;
    final at = pressMoved(
      part,
      (local.dx - _grab.dx).roundToDouble(),
      (local.dy - _grab.dy).roundToDouble(),
    );
    if (_forcing && pressOverlaps([...others, at], _press).isEmpty) return at;
    final snapped = pressSnapped(at, others, _press);
    return pressOverlaps([...others, snapped], _press).isEmpty
        ? snapped
        : pressFreeSpot(part, others, _press);
  }

  /// A typed distance from the table's edge — along it, or across.
  void _typed(String text, {required bool along}) {
    final at = _picked;
    final p = _part;
    final mm = double.tryParse(text.replaceAll(',', '.').trim());
    if (at == null || p == null || at.load == _tray || mm == null) return;
    _change(
      () => _loads[at.load][at.part] = along
          ? pressMoved(p, mm, p.y)
          : pressMoved(p, p.x, mm),
    );
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_xFocus.hasFocus || _yFocus.hasFocus) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed || keys.isMetaPressed;
    final key = event.logicalKey;
    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        if (keys.isShiftPressed) {
          _forward();
        } else {
          _back();
        }
      } else if (key == LogicalKeyboardKey.keyY) {
        _forward();
      } else if (key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.add ||
          key == LogicalKeyboardKey.numpadAdd) {
        _zoomBy(_zoomStep);
      } else if (key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.numpadSubtract) {
        _zoomBy(1 / _zoomStep);
      } else if (key == LogicalKeyboardKey.digit0) {
        setState(() => _zoom = 1);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    final at = _picked;
    if (at == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.keyR) {
      _turn();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _moveTo(_tray);
      return KeyEventResult.handled;
    }
    final step = keys.isShiftPressed ? 10.0 : 1.0;
    final delta = switch (key) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (delta == null || at.load == _tray) return KeyEventResult.ignored;
    final p = _loads[at.load][at.part];
    _change(
      () => _loads[at.load][at.part] = pressMoved(
        p,
        p.x + delta.dx,
        p.y + delta.dy,
      ),
    );
    return KeyEventResult.handled;
  }

  Future<void> _keep(List<PressLoad>? loads) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    var kept = loads;
    if (kept != null && _waiting.isNotEmpty) {
      // A part in the tray is a part the press would forget.
      final lay = await _askTray(context);
      if (lay != true || !mounted) return;
      _layRest();
      if (!_valid) return;
      kept = _result();
    }
    String? forced;
    if (kept != null && _tight) {
      if (!mounted) return;
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
            kept,
            forced: forced,
          );
      navigator.pop(true);
    } on Object catch (error) {
      if (mounted) setState(() => _busy = false);
      messenger.showFailure(error, l10n);
    }
  }

  Future<bool?> _askTray(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('pressEdit:trayAsk'),
        title: Text(l10n.pressEditTrayLeft(_waiting.length)),
        content: Text(l10n.pressEditTrayLeftBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('pressEdit:trayFill'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pressEditLayRestSave),
          ),
        ],
      ),
    );
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
                onPressed: () =>
                    setState(() => why.text = l10n.pressForceUsual),
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
    final number = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toLanguageTag(),
    );
    final valid = _valid;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.pressEdit),
          actions: [
            IconButton(
              key: const ValueKey('pressEdit:undo'),
              tooltip: l10n.pressEditUndo,
              onPressed: _undo.isEmpty ? null : _back,
              icon: const Icon(AppIcons.undo),
            ),
            IconButton(
              key: const ValueKey('pressEdit:redo'),
              tooltip: l10n.pressEditRedo,
              onPressed: _redo.isEmpty ? null : _forward,
              icon: const Icon(AppIcons.redo),
            ),
            const VerticalDivider(),
            IconButton(
              key: const ValueKey('pressEdit:zoomOut'),
              tooltip: l10n.pressEditZoomOut,
              onPressed: _zoom > _zoomMin ? () => _zoomBy(1 / _zoomStep) : null,
              icon: const Icon(AppIcons.zoomOut),
            ),
            Center(
              child: Text(
                '${(_zoom * 100).round()}%',
                key: const ValueKey('pressEdit:zoom'),
              ),
            ),
            IconButton(
              key: const ValueKey('pressEdit:zoomIn'),
              tooltip: l10n.pressEditZoomIn,
              onPressed: _zoom < _zoomMax ? () => _zoomBy(_zoomStep) : null,
              icon: const Icon(AppIcons.zoomIn),
            ),
            IconButton(
              key: const ValueKey('pressEdit:zoomFit'),
              tooltip: l10n.pressEditZoomFit,
              onPressed: () => setState(() => _zoom = 1),
              icon: const Icon(AppIcons.zoomFit),
            ),
            const VerticalDivider(),
            TextButton.icon(
              key: const ValueKey('pressEdit:reset'),
              onPressed: _busy ? null : () => _keep(null),
              icon: const Icon(AppIcons.refresh, size: AppIconSize.dense),
              label: Text(l10n.pressEditReset),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('pressEdit:save'),
              onPressed: (valid || _waiting.isNotEmpty) && !_busy
                  ? () => _keep(_result())
                  : null,
              child: Text(l10n.pressEditSave),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, box) {
            final longest = pressLongest(_press);
            final room = box.maxWidth - AppSpacing.lg * 2;
            final fit = longest <= 0 || _press.widthMm <= 0
                ? 0.0
                : math.min(room / longest, _tableMax / _press.widthMm);
            _scale = fit * _zoom;
            return Stack(
              key: _stackKey,
              children: [
                ListView(
                  physics: _dragging
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ..._top(context, number, valid),
                    for (final (i, load) in _loads.indexed) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _head(context, i, load, number),
                      const SizedBox(height: AppSpacing.xs),
                      _table(context, i, load, number),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _trayView(context),
                  ],
                ),
                ?_shadow(context),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _top(BuildContext context, NumberFormat number, bool valid) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final part = _part;
    final at = _picked;
    return [
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
      if (!valid && _loads.any((l) => l.isNotEmpty))
        Text(
          l10n.pressEditClash,
          key: const ValueKey('pressEdit:clash'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Shift, or this on a touch screen: a part stays where it is let
          // go — nearer than the gap, into the margin. Never on another
          // part or off the table.
          FilterChip(
            key: const ValueKey('pressEdit:force'),
            avatar: const Icon(AppIcons.force, size: AppIconSize.dense),
            label: Text(l10n.pressEditForce),
            tooltip: l10n.pressEditForceHint,
            selected: _force,
            onSelected: (on) => setState(() => _force = on),
          ),
          OutlinedButton.icon(
            key: const ValueKey('pressEdit:addEmpty'),
            onPressed: _addEmpty,
            icon: const Icon(AppIcons.add, size: AppIconSize.dense),
            label: Text(l10n.pressEditAddEmpty),
          ),
          OutlinedButton.icon(
            key: const ValueKey('pressEdit:layRest'),
            onPressed: _waiting.isEmpty ? null : _layRest,
            icon: const Icon(AppIcons.layRest, size: AppIconSize.dense),
            label: Text(l10n.pressEditLayRest),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (part == null || at == null)
        Text(
          l10n.pressEditHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        _picker(context, part, at),
    ];
  }

  /// The picked part: its size, exact place, and where it may go.
  Widget _picker(
    BuildContext context,
    PlacedPart part,
    ({int load, int part}) at,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onTable = at.load != _tray;
    // Made anew when the part moves, so it always shows where it is.
    Widget field(String key, String label, double value, FocusNode f) =>
        SizedBox(
          key: ValueKey(key),
          width: AppSpacing.xxxl * 2.5,
          child: TextFormField(
            key: ValueKey('$key:${value.round()}'),
            initialValue: '${value.round()}',
            focusNode: f,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, isDense: true),
            onFieldSubmitted: (text) {
              _typed(text, along: key == 'pressEdit:x');
              _focus.requestFocus();
            },
          ),
        );
    return Wrap(
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
        if (onTable) ...[
          field('pressEdit:x', l10n.pressEditFromEdge, part.x, _xFocus),
          field('pressEdit:y', l10n.pressEditFromTop, part.y, _yFocus),
          OutlinedButton(
            key: const ValueKey('pressEdit:turn'),
            onPressed: _turnable ? _turn : null,
            child: Text(
              _turnable ? l10n.pressEditRotate : l10n.pressTextured,
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('pressEdit:centre'),
            onPressed: _centre,
            icon: const Icon(AppIcons.centre, size: AppIconSize.dense),
            label: Text(l10n.pressEditCentre),
          ),
        ],
        for (var i = 0; i < _loads.length; i++)
          if (i != at.load)
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
        if (onTable)
          OutlinedButton.icon(
            key: const ValueKey('pressEdit:toTray'),
            onPressed: () => _moveTo(_tray),
            icon: const Icon(AppIcons.tray, size: AppIconSize.dense),
            label: Text(l10n.pressEditToTray),
          ),
      ],
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                load.isEmpty
                    ? l10n.pressEditEmptyLoad(i + 1)
                    : l10n.pressLoad(i + 1, number.format(section?.filmM ?? 0)),
                key: ValueKey('pressEdit:load:$i'),
                style: theme.textTheme.titleSmall,
              ),
              if (load.isEmpty)
                Text(l10n.pressEditEmptyHint, style: muted)
              else if (section != null)
                Text(
                  l10n.pressEditFill(
                    pressLoadFill(load, section.lengthMm, _press),
                  ),
                  key: ValueKey('pressEdit:fill:$i'),
                  style: muted,
                ),
            ],
          ),
        ),
        if (load.isNotEmpty)
          DropdownButton<double?>(
            key: ValueKey('pressEdit:section:$i'),
            value: _asked[i],
            isDense: true,
            onChanged: (value) => _change(() => _asked[i] = value),
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
          )
        else
          IconButton(
            key: ValueKey('pressEdit:dropEmpty:$i'),
            tooltip: l10n.pressEditDropEmpty,
            onPressed: () => _dropEmpty(i),
            icon: const Icon(AppIcons.close),
          ),
      ],
    );
  }

  Widget _table(
    BuildContext context,
    int i,
    List<PlacedPart> load,
    NumberFormat number,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final longest = pressLongest(_press);
    final clashes = pressOverlaps(load, _press);
    final tight = pressClashes(load, _press).difference(clashes);
    final amber = context.statusColors.warning;
    final section = pressSection(load, _press, asked: _asked[i]);
    final scale = _scale;
    final width = longest * scale;
    final height = _press.widthMm * scale;
    final picked = _picked;
    final guide = scheme.error;
    final label = theme.textTheme.labelSmall;
    final carriedHere = _carried != null && _dragging;

    // The millimetres to the nearest neighbour on each side of the part
    // picked (owner, 27.11.2026).
    final guides = <Widget>[];
    if (picked != null && picked.load == i && picked.part < load.length) {
      final p = load[picked.part];
      final g = pressGaps(p, _othersOf(i, picked.part), _press);
      Widget line(
        double left,
        double top,
        double w,
        double h,
        double mm, {
        required bool across,
      }) => Positioned(
        left: left * scale,
        top: top * scale,
        width: math.max(w * scale, AppStroke.hairline),
        height: math.max(h * scale, AppStroke.hairline),
        child: IgnorePointer(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: ColoredBox(color: guide)),
              Positioned(
                left: across ? AppSpacing.xxs : null,
                top: across ? null : -AppSpacing.md,
                child: Text(
                  '${mm.round()}',
                  style: label?.copyWith(color: guide),
                ),
              ),
            ],
          ),
        ),
      );
      final midX = p.x + p.width / 2;
      final midY = p.y + p.height / 2;
      if (g.left > 0) {
        guides.add(line(p.x - g.left, midY, g.left, 0, g.left, across: false));
      }
      if (g.right > 0 && g.right < longest) {
        guides.add(
          line(p.x + p.width, midY, g.right, 0, g.right, across: false),
        );
      }
      if (g.top > 0) {
        guides.add(line(midX, p.y - g.top, 0, g.top, g.top, across: true));
      }
      if (g.bottom > 0) {
        guides.add(
          line(midX, p.y + p.height, 0, g.bottom, g.bottom, across: true),
        );
      }
    }

    final table = SizedBox(
      key: _tableKey(i),
      width: width,
      height: height,
      // Clipped: a part carried off it is drawn as a shadow instead.
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: load.isEmpty
                    ? scheme.primary.withValues(alpha: AppTint.surface)
                    : scheme.surfaceContainerHighest,
                border: Border.all(
                  color: load.isEmpty ? scheme.primary : scheme.outline,
                ),
              ),
            ),
          ),
          // The film ends where its section does: the rest is bare.
          if (section != null && section.lengthMm < longest && load.isNotEmpty)
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
            if (!(carriedHere && picked == (load: i, part: k)))
              Positioned(
                left: p.x * scale,
                top: p.y * scale,
                width: p.width * scale,
                height: p.height * scale,
                child: Listener(
                  key: ValueKey('pressEdit:part:$i:$k'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _pressPart(i, k, e, scale),
                  onPointerMove: (e) => _drag(i, k, e, scale),
                  onPointerUp: (e) => _drop(i, k, e.position),
                  onPointerCancel: (e) => _drop(i, k, e.position),
                  child: _partBox(
                    context,
                    p,
                    picked: picked == (load: i, part: k),
                    clash: clashes.contains(k),
                    tight: tight.contains(k)
                        ? (_force ? amber : scheme.error)
                        : null,
                  ),
                ),
              ),
          ...guides,
        ],
      ),
    );

    // Ctrl + the wheel: the scale, not the page (owner, 27.11.2026).
    return Listener(
      onPointerSignal: (e) {
        if (e is! PointerScrollEvent) return;
        final keys = HardwareKeyboard.instance;
        if (!keys.isControlPressed && !keys.isMetaPressed) return;
        GestureBinding.instance.pointerSignalResolver.register(e, (e) {
          if (e is PointerScrollEvent) {
            _zoomBy(e.scrollDelta.dy < 0 ? _zoomStep : 1 / _zoomStep);
          }
        });
      },
      child: SingleChildScrollView(
        key: ValueKey('pressEdit:table:$i'),
        scrollDirection: Axis.horizontal,
        physics: _dragging ? const NeverScrollableScrollPhysics() : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_ruler(context, width, longest, number), table],
        ),
      ),
    );
  }

  /// The table's length in millimetres, every half metre, its end in bold.
  Widget _ruler(
    BuildContext context,
    double width,
    double longest,
    NumberFormat number,
  ) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ticks = <double>[
      for (var mm = 0.0; mm < longest - _rulerMm / 2; mm += _rulerMm) mm,
      longest,
    ];
    return SizedBox(
      width: width,
      height: AppSpacing.lg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final mm in ticks)
            Positioned(
              left: math.min(mm * _scale, width - AppSpacing.xl),
              bottom: 0,
              child: Text(
                number.format(mm),
                style: mm == longest
                    ? style?.copyWith(fontWeight: FontWeight.w800)
                    : style,
              ),
            ),
        ],
      ),
    );
  }

  Widget _partBox(
    BuildContext context,
    PlacedPart p, {
    required bool picked,
    required bool clash,
    Color? tight,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = PressMap.colourOf(p.pos);
    return DecoratedBox(
      decoration: BoxDecoration(
        // Each position its own colour, as on the map.
        color: clash
            ? scheme.errorContainer
            : colour.withValues(alpha: AppTint.pressPart),
        border: Border.all(
          color: clash ? scheme.error : tight ?? colour,
          width: picked ? AppStroke.focus * 2 : AppStroke.hairline,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${p.pos}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clash ? scheme.onErrorContainer : scheme.onSurface,
                  ),
                ),
                // Its sides as they lie: along the table × across it.
                Text(
                  '${p.width.round()}×${p.height.round()}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tray (owner, 27.11.2026): parts put aside to make room, dragged
  /// back onto any table — or laid by «Доуложить сам».
  Widget _trayView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: _trayKey,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: _waiting.isEmpty ? null : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.tray,
                size: AppIconSize.small,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _waiting.isEmpty
                      ? l10n.pressEditTrayEmpty
                      : l10n.pressEditTray(_waiting.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_waiting.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (k, p) in _waiting.indexed)
                  Listener(
                    key: ValueKey('pressEdit:tray:$k'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _pressTray(k),
                    onPointerMove: (e) => _drag(_tray, k, e, _scale),
                    onPointerUp: (e) => _drop(_tray, k, e.position),
                    onPointerCancel: (e) => _drop(_tray, k, e.position),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: PressMap.colourOf(
                          p.pos,
                        ).withValues(alpha: AppTint.pressPart),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: PressMap.colourOf(p.pos),
                          width: _picked == (load: _tray, part: k)
                              ? AppStroke.focus * 2
                              : AppStroke.hairline,
                        ),
                      ),
                      child: Text(
                        '${p.pos} · ${p.width.round()}×${p.height.round()}',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The part carried off its own table, drawn under the pointer.
  Widget? _shadow(BuildContext context) {
    final at = _carried;
    final part = _part;
    final stack = _stackKey.currentContext?.findRenderObject();
    if (at == null || part == null || stack is! RenderBox || !_dragging) {
      return null;
    }
    final local = stack.globalToLocal(at);
    return Positioned(
      left: local.dx - _grab.dx * _scale,
      top: local.dy - _grab.dy * _scale,
      width: part.width * _scale,
      height: part.height * _scale,
      child: IgnorePointer(
        child: Opacity(
          opacity: AppTint.pressPart * 2,
          child: _partBox(context, part, picked: true, clash: false),
        ),
      ),
    );
  }
}
