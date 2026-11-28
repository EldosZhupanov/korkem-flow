import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/saw_cutting/data/saw_cutting_repository.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The panel saw as the shop has it (owner, 28.11.2026), every figure its
/// own setting: the kerf, the edge trim, the smallest offcut kept, the
/// fence's side, whether a band comes off a size, and a sheet per
/// thickness — its height going away from the sawyer, as it is drawn.
class SawSettingsScreen extends ConsumerWidget {
  const SawSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppScreen(
      title: l10n.sawSettingsTitle,
      body: ref
          .watch(sawSettingsProvider)
          .when(
            loading: () => const ListSkeleton(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(sawSettingsProvider),
            ),
            data: (settings) => _Form(settings: settings),
          ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.settings});

  final SawSettings settings;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

typedef _SheetRow = (
  TextEditingController thickness,
  TextEditingController height,
  TextEditingController width,
);

class _FormState extends ConsumerState<_Form> {
  late final _kerf = _field(widget.settings.kerfMm);
  late final _trim = _field(widget.settings.trimMm);
  late final _minL = _field(widget.settings.offcutMinLengthMm);
  late final _minW = _field(widget.settings.offcutMinWidthMm);
  late FenceSide _fence = widget.settings.fence;
  late bool _deduct = widget.settings.edgeDeduct;
  late final List<_SheetRow> _sheets = [
    for (final s in widget.settings.sheets)
      (_field(s.thicknessMm), _field(s.heightMm), _field(s.widthMm)),
  ];
  bool _saving = false;

  static TextEditingController _field(double value) => TextEditingController(
    text: value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : '$value'.replaceAll('.', ','),
  );

  static double? _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim());

  @override
  void dispose() {
    for (final c in [_kerf, _trim, _minL, _minW]) {
      c.dispose();
    }
    for (final (a, b, c) in _sheets) {
      a.dispose();
      b.dispose();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final numbers = [_kerf, _trim, _minL, _minW].map(_number).toList();
    final sheets = [
      for (final (t, h, w) in _sheets)
        (t: _number(t), h: _number(h), w: _number(w)),
    ];
    if (numbers.any((n) => n == null) ||
        sheets.any((s) => s.t == null || s.h == null || s.w == null)) {
      messenger.showFailureMessage(l10n.materialStockFillAll);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sawCuttingRepositoryProvider)
          .saveSettings(
            kerfMm: numbers[0]!,
            trimMm: numbers[1]!,
            offcutMinLengthMm: numbers[2]!,
            offcutMinWidthMm: numbers[3]!,
            fence: _fence,
            edgeDeduct: _deduct,
            sheets: [
              for (final s in sheets)
                SawSheet(thicknessMm: s.t!, heightMm: s.h!, widthMm: s.w!),
            ],
          );
      ref.invalidate(sawSettingsProvider);
      messenger.showDone(l10n.sawSettingsSaved);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberField(String key, String label, TextEditingController c) =>
      TextField(
        key: ValueKey(key),
        controller: c,
        enabled: widget.settings.canEdit,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEdit = widget.settings.canEdit;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _numberField('sawKerf', l10n.sawKerf, _kerf),
              _numberField('sawTrim', l10n.sawTrim, _trim),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.sawOffcutFrom, style: theme.textTheme.labelLarge),
              Row(
                children: [
                  Expanded(child: _numberField('sawMinL', '', _minL)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('×'),
                  ),
                  Expanded(child: _numberField('sawMinW', '', _minW)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.sawFence, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<FenceSide>(
                key: const ValueKey('sawFence'),
                segments: [
                  ButtonSegment(
                    value: FenceSide.left,
                    label: Text(l10n.sawFenceLeft),
                  ),
                  ButtonSegment(
                    value: FenceSide.right,
                    label: Text(l10n.sawFenceRight),
                  ),
                ],
                selected: {_fence},
                onSelectionChanged: canEdit
                    ? (v) => setState(() => _fence = v.first)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                key: const ValueKey('sawDeduct'),
                contentPadding: EdgeInsets.zero,
                value: _deduct,
                onChanged: canEdit ? (v) => setState(() => _deduct = v) : null,
                title: Text(l10n.sawEdgeDeduct),
                subtitle: Text(l10n.sawEdgeDeductHint),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionLabel(l10n.sawSheetsTitle),
              Text(
                l10n.sawDefaultSheet(
                  widget.settings.defaultHeightMm.round(),
                  widget.settings.defaultWidthMm.round(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              for (final (i, (t, h, w)) in _sheets.indexed)
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'sawSheetT:$i',
                        l10n.sawSheetThickness,
                        t,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _numberField(
                        'sawSheetH:$i',
                        l10n.sawSheetHeight,
                        h,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _numberField('sawSheetW:$i', l10n.sawSheetWidth, w),
                    ),
                    if (canEdit)
                      IconButton(
                        tooltip: l10n.actionCancel,
                        icon: const Icon(AppIcons.delete),
                        onPressed: () => setState(() => _sheets.removeAt(i)),
                      ),
                  ],
                ),
              if (canEdit) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('sawAddSheet'),
                    onPressed: () => setState(
                      () => _sheets.add((
                        TextEditingController(),
                        _field(widget.settings.defaultHeightMm),
                        _field(widget.settings.defaultWidthMm),
                      )),
                    ),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.sawAddSheet),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const ValueKey('sawSettingsSave'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.facadePricesSave),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
