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
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The press as the shop has it: working area, margin, gap, and the sections
/// film is ordered in. Every layout is counted from these.
class PressSettingsScreen extends ConsumerWidget {
  const PressSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppScreen(
      title: l10n.pressSettingsTitle,
      body: ref
          .watch(pressSettingsProvider)
          .when(
            loading: () => const ListSkeleton(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(pressSettingsProvider),
            ),
            data: (settings) => _Form(settings: settings),
          ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.settings});

  final PressSettings settings;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final TextEditingController _length = _field(widget.settings.lengthMm);
  late final TextEditingController _width = _field(widget.settings.widthMm);
  late final TextEditingController _margin = _field(widget.settings.marginMm);
  late final TextEditingController _gap = _field(widget.settings.gapMm);
  late final List<(TextEditingController, TextEditingController)> _sections = [
    for (final s in widget.settings.sections)
      (_field(s.filmM), _field(s.lengthMm)),
  ];
  bool _saving = false;

  static TextEditingController _field(double value) => TextEditingController(
    text: value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value',
  );

  static double? _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim());

  @override
  void dispose() {
    for (final c in [_length, _width, _margin, _gap]) {
      c.dispose();
    }
    for (final (film, length) in _sections) {
      film.dispose();
      length.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final numbers = [_length, _width, _margin, _gap].map(_number).toList();
    final sections = [
      for (final (film, length) in _sections)
        (filmM: _number(film), lengthMm: _number(length)),
    ];
    if (numbers.any((n) => n == null) ||
        sections.isEmpty ||
        sections.any((s) => s.filmM == null || s.lengthMm == null)) {
      messenger.showFailureMessage(l10n.materialStockFillAll);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(pressLayoutRepositoryProvider)
          .saveSettings(
            lengthMm: numbers[0]!,
            widthMm: numbers[1]!,
            marginMm: numbers[2]!,
            gapMm: numbers[3]!,
            sections: [
              for (final s in sections)
                (filmM: s.filmM!, lengthMm: s.lengthMm!),
            ],
          );
      ref.invalidate(pressSettingsProvider);
      messenger.showDone(l10n.pressSaved);
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _numberField('pressLength', l10n.pressLength, _length),
              _numberField('pressWidth', l10n.pressWidth, _width),
              _numberField('pressMargin', l10n.pressMargin, _margin),
              _numberField('pressGap', l10n.pressGap, _gap),
              const SizedBox(height: AppSpacing.xl),
              SectionLabel(l10n.pressSections),
              for (final (i, (film, length)) in _sections.indexed)
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'pressSectionFilm:$i',
                        l10n.pressSectionFilm,
                        film,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _numberField(
                        'pressSectionLength:$i',
                        l10n.pressLength,
                        length,
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        tooltip: l10n.actionCancel,
                        icon: const Icon(AppIcons.delete),
                        onPressed: _sections.length > 1
                            ? () => setState(() => _sections.removeAt(i))
                            : null,
                      ),
                  ],
                ),
              if (canEdit) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('pressAddSection'),
                    onPressed: () => setState(
                      () => _sections.add(
                        (TextEditingController(), TextEditingController()),
                      ),
                    ),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.pressAddSection),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const ValueKey('pressSave'),
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
