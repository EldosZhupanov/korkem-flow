import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/materials/data/materials_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class MaterialCreateSheet extends ConsumerStatefulWidget {
  const MaterialCreateSheet({super.key});

  @override
  ConsumerState<MaterialCreateSheet> createState() =>
      _MaterialCreateSheetState();
}

class _MaterialCreateSheetState extends ConsumerState<MaterialCreateSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _manufacturer = TextEditingController();
  final _decor = TextEditingController();
  final _thickness = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _edgeWidth = TextEditingController();
  final _fits = TextEditingController();
  String _kind = 'board';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _manufacturer,
      _decor,
      _thickness,
      _width,
      _height,
      _edgeWidth,
      _fits,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  Widget _dimension(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (!required && (value?.trim().isEmpty ?? true)) return null;
          final number = _number(controller);
          return number == null || !number.isFinite || number <= 0
              ? l10n.materialsPositiveDimension
              : null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(materialsRepositoryProvider)
          .create(
            name: _name.text,
            kind: _kind,
            manufacturer: _manufacturer.text.trim(),
            decorCode: _decor.text.trim(),
            thicknessMm: _number(_thickness),
            sheetWidthMm: _kind == 'board' ? _number(_width) : null,
            sheetHeightMm: _kind == 'board' ? _number(_height) : null,
            edgeWidthMm: _kind == 'edge' ? _number(_edgeWidth) : null,
            fitsThicknessMm: _kind == 'edge' ? _number(_fits) : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on FrappeException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.materialsAdd,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: l10n.materialsFilterKind,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'board',
                      child: Text(l10n.materialKindBoard),
                    ),
                    DropdownMenuItem(
                      value: 'edge',
                      child: Text(l10n.materialKindEdge),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (kind) => setState(() => _kind = kind!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: InputDecoration(labelText: l10n.materialsName),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : l10n.authFieldRequired,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _manufacturer,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: l10n.materialsManufacturer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _decor,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: l10n.materialsDecorCode,
                  ),
                ),
                _dimension(
                  _thickness,
                  l10n.materialsThicknessInput,
                  required: _kind == 'board',
                ),
                if (_kind == 'board') ...[
                  _dimension(_width, l10n.materialsSheetWidthInput),
                  _dimension(_height, l10n.materialsSheetHeightInput),
                ] else ...[
                  _dimension(
                    _fits,
                    l10n.materialsFitsThicknessInput,
                    required: true,
                  ),
                  _dimension(_edgeWidth, l10n.materialsEdgeWidthInput),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.actionCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.materialsSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
