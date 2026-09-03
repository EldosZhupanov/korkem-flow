import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/items/application/items_controller.dart';
import 'package:korkem_flow/features/items/data/items_repository.dart';
import 'package:korkem_flow/features/items/domain/item.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying the items catalog with search, price configuration,
/// and item creation.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(itemsListProvider);

    return AppScreen(
      title: l10n.itemsTitle,
      subtitle: l10n.itemsSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.itemsAddItem,
          icon: const Icon(AppIcons.add),
          onPressed: () => _openCreateDialog(context),
        ),
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(itemsListProvider),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(itemsListProvider);
          await ref.read(itemsListProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(itemsSearchQueryProvider.notifier).query = val;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                itemsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyView(
                        icon: AppIcons.item,
                        title: l10n.itemsEmptyTitle,
                        message: l10n.itemsEmptyMessage,
                        actionLabel: l10n.itemsAddItem,
                        onAction: () => _openCreateDialog(context),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in items) ...[
                          _ItemTile(
                            item: item,
                            onEditPrice: () => _openSetPriceDialog(
                              context,
                              item,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                  loading: () => const ListSkeleton(),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(itemsListProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateItemDialog(),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(this.context).showDone(result);
    }
  }

  Future<void> _openSetPriceDialog(BuildContext context, Item item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _SetPriceDialog(item: item),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(this.context).showDone(result);
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: l10n.itemsSearchHint,
        prefixIcon: const Icon(AppIcons.search, size: AppIconSize.small),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(AppIcons.close, size: AppIconSize.small),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onEditPrice,
  });

  final Item item;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.code.isNotEmpty && item.code != item.name) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusChip(
                  label: item.unit.isNotEmpty ? item.unit : '—',
                  intent: StatusIntent.neutral,
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: AppStroke.hairline),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${l10n.itemsPriceLabelShort}: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Flexible(
                        child: item.salePrice != null
                            ? Text(
                                money.format(item.salePrice),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                l10n.itemsPriceOnRequest,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.itemsSetPriceTitle,
                  icon: const Icon(AppIcons.edit, size: AppIconSize.small),
                  onPressed: onEditPrice,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateItemDialog extends ConsumerStatefulWidget {
  const _CreateItemDialog();

  @override
  ConsumerState<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends ConsumerState<_CreateItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedUnit;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final unit = _selectedUnit!.trim();
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final description = _descController.text.trim();
    final priceStr = _priceController.text.trim();
    final salePrice = priceStr.isNotEmpty ? double.tryParse(priceStr) : null;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final item = Item(
        code: code,
        name: name,
        unit: unit,
        description: description,
        salePrice: salePrice,
      );

      await ref.read(itemsRepositoryProvider).create(item);
      ref.invalidate(itemsListProvider);

      if (mounted) {
        Navigator.of(context).pop(l10n.itemsCreateSuccess);
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unitsAsync = ref.watch(itemsUnitsProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.itemsCreateTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.warning,
                          size: AppIconSize.small,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.itemsNameLabel,
                    hintText: l10n.itemsNameHint,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.itemsNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                unitsAsync.when(
                  data: (units) => DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: l10n.itemsUnitLabel,
                      hintText: l10n.itemsUnitHint,
                    ),
                    items: [
                      for (final u in units)
                        DropdownMenuItem(
                          value: u.unit,
                          child: Text(u.label),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedUnit = val),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.itemsUnitRequired;
                      }
                      return null;
                    },
                  ),
                  loading: () => InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.itemsUnitLabel,
                    ),
                    child: Text(
                      l10n.itemsUnitsLoading,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  error: (_, _) => InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.itemsUnitLabel,
                      errorText: l10n.itemsUnitsLoadError,
                    ),
                    child: const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: l10n.itemsCodeLabel,
                    hintText: l10n.itemsCodeHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.itemsDescriptionLabel,
                    hintText: l10n.itemsDescriptionHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.itemsPriceLabel,
                    hintText: l10n.itemsPriceHint,
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final n = double.tryParse(val.trim());
                      if (n == null || n < 0) {
                        return l10n.itemsPriceInvalid;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: AppIconSize.small,
                          height: AppIconSize.small,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.check),
                  label: Text(l10n.itemsAddItem),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetPriceDialog extends ConsumerStatefulWidget {
  const _SetPriceDialog({required this.item});

  final Item item;

  @override
  ConsumerState<_SetPriceDialog> createState() => _SetPriceDialogState();
}

class _SetPriceDialogState extends ConsumerState<_SetPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.salePrice != null
          ? widget.item.salePrice!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(itemsRepositoryProvider).setPrice(widget.item.code, price);
      ref.invalidate(itemsListProvider);

      if (mounted) {
        Navigator.of(context).pop(l10n.itemsPriceUpdated);
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.itemsSetPriceTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item.name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.itemsPriceLabelShort,
                hintText: l10n.itemsPriceHint,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return l10n.itemsPriceRequired;
                }
                final n = double.tryParse(val.trim());
                if (n == null || n < 0) {
                  return l10n.itemsPriceInvalid;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(l10n.itemsSetPriceAction),
        ),
      ],
    );
  }
}
