import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/bazis/application/bazis_controller.dart';
import 'package:korkem_flow/features/bazis/domain/bazis_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Lightweight container for picked CAD export bytes.
@immutable
class BazisPickedFile {
  const BazisPickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Screen for inspecting a Bazis CAD export XML and creating an ERPNext BOM.
///
/// Workflow is strictly two-step:
/// 1. Read (inspect) file and display parts, materials, and operations
///    to verify.
/// 2. Import into ERPNext, visibly surfacing materials missing quantity and
///    operations awaiting workstation assignment.
class BazisImportScreen extends ConsumerStatefulWidget {
  const BazisImportScreen({
    this.salesOrder,
    this.onPickFileForTesting,
    super.key,
  });

  final String? salesOrder;

  /// Optional file picker hook for widget tests.
  final Future<BazisPickedFile?> Function()? onPickFileForTesting;

  @override
  ConsumerState<BazisImportScreen> createState() => _BazisImportScreenState();
}

class _BazisImportScreenState extends ConsumerState<BazisImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(bazisControllerProvider.notifier)
          .setSalesOrder(widget.salesOrder);
    });
  }

  Future<void> _pickFile() async {
    try {
      String? name;
      List<int>? bytes;

      if (widget.onPickFileForTesting != null) {
        final picked = await widget.onPickFileForTesting!();
        if (picked != null) {
          name = picked.name;
          bytes = picked.bytes;
        }
      } else {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xml', 'txt'],
        );
        if (files.isNotEmpty) {
          final file = files.first;
          name = file.name;
          bytes = await file.readAsBytes();
        }
      }

      if (name == null || bytes == null || bytes.isEmpty) {
        return;
      }

      await ref
          .read(bazisControllerProvider.notifier)
          .loadFile(
            filename: name,
            bytes: bytes,
          );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFailure(
          e,
          AppLocalizations.of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(bazisControllerProvider);

    return AppScreen(
      title: l10n.bazisImportTitle,
      subtitle: l10n.bazisImportSubtitle,
      actions: [
        if (state.hasFile)
          IconButton(
            tooltip: l10n.bazisChangeFileAction,
            icon: const Icon(AppIcons.refresh),
            onPressed: () => ref.read(bazisControllerProvider.notifier).reset(),
          ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.isImported)
                _ImportSuccessView(
                  result: state.importResult!,
                  onImportAnother: () =>
                      ref.read(bazisControllerProvider.notifier).reset(),
                )
              else if (state.isInspected)
                _InspectedPreviewView(
                  filename: state.filename!,
                  result: state.inspectResult!,
                  isImporting: state.isImporting,
                  importError: state.importError,
                  onChangeFile: _pickFile,
                  onImport: () => ref
                      .read(bazisControllerProvider.notifier)
                      .importSpecification(),
                )
              else
                _FilePickerPromptView(
                  isInspecting: state.isInspecting,
                  inspectError: state.inspectError,
                  onPickFile: _pickFile,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickerPromptView extends StatelessWidget {
  const _FilePickerPromptView({
    required this.isInspecting,
    required this.inspectError,
    required this.onPickFile,
  });

  final bool isInspecting;
  final String? inspectError;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (isInspecting) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.bazisInspectingFile,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inspectError != null) ...[
            _ErrorAlert(message: inspectError!),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: AppSpacing.xxl,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(
                      AppIcons.attachment,
                      size: AppIconSize.normal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.bazisImportTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.bazisPickFileHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(AppIcons.attachment),
                    label: Text(l10n.bazisPickFileAction),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectedPreviewView extends StatelessWidget {
  const _InspectedPreviewView({
    required this.filename,
    required this.result,
    required this.isImporting,
    required this.importError,
    required this.onChangeFile,
    required this.onImport,
  });

  final String filename;
  final BazisInspectResult result;
  final bool isImporting;
  final String? importError;
  final VoidCallback onChangeFile;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totals = result.totals;

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FileInfoHeader(
            filename: filename,
            summary: l10n.bazisTotalsSummary(
              totals.products,
              totals.parts,
              totals.materials,
              totals.operations,
            ),
            onChangeFile: isImporting ? null : onChangeFile,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final product in result.products) ...[
            _ProductPreviewCard(product: product),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (importError != null) ...[
            _ErrorAlert(message: importError!),
            const SizedBox(height: AppSpacing.lg),
          ],
          FilledButton.icon(
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox.square(
                    dimension: AppIconSize.small,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.focus,
                    ),
                  )
                : const Icon(AppIcons.check),
            label: Text(
              isImporting
                  ? l10n.bazisCreatingSpecification
                  : l10n.bazisCreateSpecificationAction,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _FileInfoHeader extends StatelessWidget {
  const _FileInfoHeader({
    required this.filename,
    required this.summary,
    required this.onChangeFile,
  });

  final String filename;
  final String summary;
  final VoidCallback? onChangeFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.attachment,
                      color: theme.colorScheme.primary,
                      size: AppIconSize.normal,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        filename,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onChangeFile != null)
                TextButton(
                  onPressed: onChangeFile,
                  child: Text(l10n.bazisChangeFileAction),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPreviewCard extends StatefulWidget {
  const _ProductPreviewCard({required this.product});

  final BazisProduct product;

  @override
  State<_ProductPreviewCard> createState() => _ProductPreviewCardState();
}

class _ProductPreviewCardState extends State<_ProductPreviewCard> {
  int _activeTab = 0; // 0: parts, 1: materials, 2: operations

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    final locale = Localizations.localeOf(context).languageCode;
    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            product.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              if (product.article != null)
                Text(
                  l10n.bazisArticleLabel(product.article!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (product.order != null)
                Text(
                  l10n.bazisOrderLabel(product.order!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (product.qty != null)
                Text(
                  l10n.bazisQtyLabel(
                    product.qty! % 1 == 0
                        ? product.qty!.toInt().toString()
                        : product.qty!.toString(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (product.price != null && product.price! > 0)
                Text(
                  l10n.bazisPriceLabel(money.format(product.price)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.bazisPartsTab(product.parts.length)),
                icon: const Icon(AppIcons.task, size: AppIconSize.dense),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.bazisMaterialsTab(product.materials.length)),
                icon: const Icon(AppIcons.item, size: AppIconSize.dense),
              ),
              ButtonSegment(
                value: 2,
                label: Text(
                  l10n.bazisOperationsTab(product.operations.length),
                ),
                icon: const Icon(AppIcons.workOrder, size: AppIconSize.dense),
              ),
            ],
            selected: {_activeTab},
            onSelectionChanged: (selected) {
              setState(() => _activeTab = selected.first);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          switch (_activeTab) {
            0 => _PartsList(parts: product.parts),
            1 => _MaterialsList(materials: product.materials),
            _ => _OperationsList(operations: product.operations),
          },
        ],
      ),
    );
  }
}

class _PartsList extends StatelessWidget {
  const _PartsList({required this.parts});

  final List<BazisPart> parts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (parts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          l10n.bazisEmptyParts,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parts.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final part = parts[index];
        final dims =
            '${part.length?.toStringAsFixed(0) ?? '—'} × '
            '${part.width?.toStringAsFixed(0) ?? '—'} × '
            '${part.thickness?.toStringAsFixed(0) ?? '—'} мм';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    part.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (part.qty != null)
                  Text(
                    '${part.qty! % 1 == 0 ? part.qty!.toInt() : part.qty} шт.',
                    style: AppTypography.tabular(
                      theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ) ??
                          const TextStyle(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (part.block != null)
                  StatusChip(
                    label: part.block!,
                    intent: StatusIntent.neutral,
                  ),
                if (part.code != null)
                  Text(
                    part.code!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  dims,
                  style: AppTypography.tabular(
                    theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ) ??
                        const TextStyle(),
                  ),
                ),
              ],
            ),
            if (part.edges.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.bazisPartEdges(part.edges.join(', ')),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MaterialsList extends StatelessWidget {
  const _MaterialsList({required this.materials});

  final List<BazisMaterial> materials;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (materials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          l10n.bazisEmptyMaterials,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: materials.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final mat = materials[index];
        final val = mat.qty;
        final qtyStr = val != null
            ? '${val % 1 == 0 ? val.toInt() : val} ${mat.unit ?? ''}'.trim()
            : '—';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mat.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (mat.syncId != null)
                        Text(
                          mat.syncId!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (mat.owner != null)
                        Text(
                          mat.owner!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              qtyStr,
              style: AppTypography.tabular(
                theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OperationsList extends StatelessWidget {
  const _OperationsList({required this.operations});

  final List<BazisOperation> operations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (operations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          l10n.bazisEmptyOperations,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: operations.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final op = operations[index];
        final minsStr = op.minutes != null
            ? l10n.bazisOperationMinutes(
                op.minutes! % 1 == 0
                    ? op.minutes!.toInt().toString()
                    : op.minutes!.toString(),
              )
            : '';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                op.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (minsStr.isNotEmpty)
              Text(
                minsStr,
                style: AppTypography.tabular(
                  theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ) ??
                      const TextStyle(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ImportSuccessView extends StatelessWidget {
  const _ImportSuccessView({
    required this.result,
    required this.onImportAnother,
  });

  final BazisImportResult result;
  final VoidCallback onImportAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.check,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: AppIconSize.normal,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.bazisImportSuccessTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final prod in result.products) ...[
            _ImportedProductCard(product: prod),
            const SizedBox(height: AppSpacing.lg),
          ],
          OutlinedButton.icon(
            onPressed: onImportAnother,
            icon: const Icon(AppIcons.add),
            label: Text(l10n.bazisImportAnotherAction),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ImportedProductCard extends StatelessWidget {
  const _ImportedProductCard({required this.product});

  final BazisImportedProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.product,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.bazisItemDocLabel(product.item),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      l10n.bazisBomDocLabel(product.bom),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: product.isUpdated
                    ? l10n.bazisBomStatusUpdated
                    : l10n.bazisBomStatusCreated,
                intent: product.isUpdated
                    ? StatusIntent.info
                    : StatusIntent.success,
              ),
            ],
          ),

          // Critical point 1: materials_without_quantity
          if (product.materialsWithoutQuantity.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(
                  alpha: AppTint.surface,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(
                    alpha: AppTint.ornamentOnDark,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.danger,
                        color: theme.colorScheme.error,
                        size: AppIconSize.small,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.bazisMaterialsWithoutQtyAlert,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in product.materialsWithoutQuantity)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        '• $item',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Critical point 2: operations_awaiting_workstation
          if (product.operationsAwaitingWorkstation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.info,
                        color: theme.colorScheme.primary,
                        size: AppIconSize.small,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.bazisOperationsAwaitingWorkstationAlert,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final op in product.operationsAwaitingWorkstation)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        '• $op',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            children: [
              Text(
                '${l10n.bazisMaterialsTab(product.materials.length)}: '
                '${product.materials.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${l10n.bazisOperationsTab(product.operations.length)}: '
                '${product.operations.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorAlert extends StatelessWidget {
  const _ErrorAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.danger,
            color: theme.colorScheme.onErrorContainer,
            size: AppIconSize.normal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
