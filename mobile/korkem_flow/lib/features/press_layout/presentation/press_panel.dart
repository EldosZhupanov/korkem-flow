import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The press panel beside the layout (owner, 13.11.2026: «как в Cutting»):
/// the table, the margin, the gap, the sections; how hard and which way to
/// lay the parts. Each change is tried at once; it is kept for this order
/// alone, or for the press — every new layout.
class PressPanel extends StatefulWidget {
  const PressPanel({
    required this.tune,
    required this.tried,
    required this.busy,
    required this.canSavePress,
    required this.onChanged,
    required this.onReset,
    required this.onKeepForOrder,
    required this.onKeepForPress,
    super.key,
  });

  final PressTune tune;

  /// Something differs from the press and was laid out.
  final bool tried;
  final bool busy;
  final bool canSavePress;
  final ValueChanged<PressTune> onChanged;
  final VoidCallback onReset;
  final VoidCallback onKeepForOrder;
  final VoidCallback onKeepForPress;

  @override
  State<PressPanel> createState() => _PressPanelState();
}

class _PressPanelState extends State<PressPanel> {
  late final TextEditingController _length = _field(widget.tune.lengthMm);
  late final TextEditingController _width = _field(widget.tune.widthMm);
  late final TextEditingController _margin = _field(widget.tune.marginMm);
  late final TextEditingController _gap = _field(widget.tune.gapMm);
  late final List<(TextEditingController, TextEditingController)> _sections = [
    for (final s in widget.tune.sections)
      (_metresField(s.filmM), _field(s.lengthMm)),
  ];

  static TextEditingController _field(double v) =>
      TextEditingController(text: v.round().toString());

  static TextEditingController _metresField(double v) =>
      TextEditingController(text: v.toString());

  static double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_length, _width, _margin, _gap]) {
      c.dispose();
    }
    for (final (a, b) in _sections) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  /// The figures as typed; a field not a number yet leaves its own.
  void _changed() {
    final t = widget.tune;
    widget.onChanged(
      t.copyWith(
        lengthMm: _n(_length) ?? t.lengthMm,
        widthMm: _n(_width) ?? t.widthMm,
        marginMm: _n(_margin) ?? t.marginMm,
        gapMm: _n(_gap) ?? t.gapMm,
        sections: [
          for (final (m, l) in _sections)
            if ((_n(m) ?? 0) > 0 && (_n(l) ?? 0) > 0)
              (filmM: _n(m)!, lengthMm: _n(l)!),
        ],
      ),
    );
  }

  Widget _number(String key, String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      key: ValueKey('pressTune:$key'),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _changed(),
      decoration: InputDecoration(isDense: true, labelText: label),
    ),
  );

  Widget _choices<T>(
    String key,
    List<(T, String)> options,
    T value,
    ValueChanged<T> onPick,
  ) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final (v, label) in options)
        ChoiceChip(
          key: ValueKey('pressTune:$key:$v'),
          label: Text(label),
          selected: value == v,
          onSelected: (_) => onPick(v),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = widget.tune;
    final head = theme.textTheme.titleSmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pressPanelTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _number('length', l10n.pressLength, _length),
            _number('width', l10n.pressWidth, _width),
            _number('margin', l10n.pressMargin, _margin),
            _number('gap', l10n.pressGap, _gap),
            Slider(
              key: const ValueKey('pressTune:gapSlider'),
              value: t.gapMm.clamp(0, 200),
              max: 200,
              divisions: 40,
              label: l10n.pressMm(t.gapMm.round()),
              onChanged: (v) {
                _gap.text = v.round().toString();
                _changed();
              },
            ),
            Text(l10n.pressSections, style: head),
            for (final (i, (m, l)) in _sections.indexed)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('pressTune:section:$i:m'),
                      controller: m,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      ],
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: l10n.pressUnitM,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      key: ValueKey('pressTune:section:$i:l'),
                      controller: l,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: l10n.pressUnitMm,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.pressSectionRemove,
                    icon: const Icon(AppIcons.close, size: AppIconSize.dense),
                    onPressed: _sections.length <= 1
                        ? null
                        : () {
                            final gone = _sections.removeAt(i);
                            _changed();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              gone.$1.dispose();
                              gone.$2.dispose();
                            });
                          },
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('pressTune:addSection'),
                onPressed: () => setState(
                  () => _sections.add(
                    (TextEditingController(), TextEditingController()),
                  ),
                ),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.pressAddSection),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.pressLevel, style: head),
            _choices<PressLevel>(
              'level',
              [
                (PressLevel.fast, l10n.pressLevelFast),
                (PressLevel.smart, l10n.pressLevelSmart),
                (PressLevel.max, l10n.pressLevelMax),
              ],
              t.level,
              (v) => widget.onChanged(t.copyWith(level: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.pressDirection, style: head),
            _choices<PressDirection>(
              'direction',
              [
                (PressDirection.any, l10n.pressDirectionAny),
                (PressDirection.along, l10n.pressDirectionAlong),
                (PressDirection.across, l10n.pressDirectionAcross),
              ],
              t.direction,
              (v) => widget.onChanged(t.copyWith(direction: v)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.pressRotate, style: head),
            _choices<bool>(
              'rotate',
              [(true, l10n.pressRotateYes), (false, l10n.pressRotateNo)],
              t.rotate,
              (v) => widget.onChanged(t.copyWith(rotate: v)),
            ),
            Text(
              l10n.pressRotateTextured,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.busy) const LinearProgressIndicator(),
            if (widget.tried) ...[
              OutlinedButton(
                key: const ValueKey('pressTune:keepOrder'),
                onPressed: widget.busy ? null : widget.onKeepForOrder,
                child: Text(l10n.pressKeepForOrder),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (widget.canSavePress)
                FilledButton(
                  key: const ValueKey('pressTune:keepPress'),
                  onPressed: widget.busy ? null : widget.onKeepForPress,
                  child: Text(l10n.pressKeepForPress),
                ),
              Text(
                l10n.pressKeepForPressHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                key: const ValueKey('pressTune:reset'),
                onPressed: widget.onReset,
                child: Text(l10n.pressTuneReset),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
