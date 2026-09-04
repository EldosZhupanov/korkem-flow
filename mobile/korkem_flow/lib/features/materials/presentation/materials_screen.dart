import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/search/recent_searches.dart';
import 'package:korkem_flow/features/materials/application/materials_controller.dart';
import 'package:korkem_flow/features/materials/domain/material_item.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Read-only catalogue of materials (boards and edges) with search and filters.
class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(materialsFilterProvider);
    final controller = ref.read(materialsControllerProvider.notifier);

    return AppScreen(
      title: l10n.materialsTitle,
      subtitle: l10n.materialsSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: () =>
              ref.read(materialsControllerProvider.notifier).refresh(),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: AppSearchField(
              initialValue: filter.query,
              hintText: l10n.materialsSearchHint,
              recentScope: SearchScope.materials,
              onChanged: (value) =>
                  ref.read(materialsFilterProvider.notifier).setQuery(value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                FilterChip(
                  key: const ValueKey('filter:all'),
                  label: Text(l10n.materialsFilterAll),
                  selected: !filter.isFiltered,
                  onSelected: (_) =>
                      ref.read(materialsFilterProvider.notifier).clear(),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:board'),
                  avatar: const Icon(
                    AppIcons.board,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.materialsFilterBoards),
                  selected: filter.kind == MaterialKind.board,
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setKind(selected ? MaterialKind.board : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:edge'),
                  avatar: const Icon(
                    AppIcons.edge,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.materialsFilterEdges),
                  selected: filter.kind == MaterialKind.edge,
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setKind(selected ? MaterialKind.edge : null),
                ),
                const SizedBox(width: AppSpacing.md),
                FilterChip(
                  key: const ValueKey('filter:thickness:16'),
                  label: Text(l10n.materialsFilterThickness16),
                  selected: filter.thickness == 16,
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setThickness(selected ? 16 : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:thickness:18'),
                  label: Text(l10n.materialsFilterThickness18),
                  selected: filter.thickness == 18,
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setThickness(selected ? 18 : null),
                ),
                const SizedBox(width: AppSpacing.md),
                FilterChip(
                  key: const ValueKey('filter:color:white'),
                  label: Text(l10n.materialsColorWhite),
                  selected: filter.colorFamily == 'white',
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setColorFamily(selected ? 'white' : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:color:wood'),
                  label: Text(l10n.materialsColorWood),
                  selected: filter.colorFamily == 'wood',
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setColorFamily(selected ? 'wood' : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:color:grey'),
                  label: Text(l10n.materialsColorGrey),
                  selected: filter.colorFamily == 'grey',
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setColorFamily(selected ? 'grey' : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:color:black'),
                  label: Text(l10n.materialsColorBlack),
                  selected: filter.colorFamily == 'black',
                  onSelected: (selected) => ref
                      .read(materialsFilterProvider.notifier)
                      .setColorFamily(selected ? 'black' : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: PagedListView<MaterialItem>(
              state: ref.watch(materialsControllerProvider),
              onRefresh: controller.refresh,
              onLoadMore: controller.loadMore,
              itemBuilder: (context, material) => MaterialCard(
                key: ValueKey('material:${material.id}'),
                material: material,
              ),
              emptyView: (context) => ListEmptyView(
                icon: AppIcons.material,
                title: filter.isFiltered
                    ? l10n.materialsEmptyFilteredTitle
                    : l10n.materialsEmptyTitle,
                message: filter.isFiltered
                    ? l10n.materialsEmptyFilteredMessage
                    : l10n.materialsEmptyMessage,
                onRefresh: controller.refresh,
                onClearFilter: filter.isFiltered
                    ? () => ref.read(materialsFilterProvider.notifier).clear()
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card representing a single material row in the catalogue.
class MaterialCard extends StatelessWidget {
  const MaterialCard({required this.material, super.key});

  final MaterialItem material;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final thickness = material.formattedThickness(l10n);
    final sheetDimensions = material.formattedSheetDimensions(l10n);
    final fitsThickness = material.isEdge
        ? material.formattedFitsThickness(l10n)
        : null;
    final edgeWidth = material.isEdge
        ? material.formattedEdgeWidth(l10n)
        : null;
    final colorFamily = material.localizedColorFamily(l10n);

    final metadata = <EntityMeta>[
      if (thickness != null)
        EntityMeta(
          icon: Symbols.straighten_rounded,
          label: thickness,
        ),
      if (fitsThickness != null)
        EntityMeta(
          icon: Symbols.link_rounded,
          label: fitsThickness,
        ),
      if (edgeWidth != null)
        EntityMeta(
          icon: Symbols.straighten_rounded,
          label: edgeWidth,
        ),
      if (material.isBoard && sheetDimensions != null)
        EntityMeta(
          icon: Symbols.aspect_ratio_rounded,
          label: sheetDimensions,
        ),
      if (colorFamily != null)
        EntityMeta(
          icon: Symbols.palette_rounded,
          label: colorFamily,
        ),
    ];

    return EntityCard(
      title: material.displayTitle,
      subtitle: material.manufacturer,
      statusLabel: material.isBoard
          ? l10n.materialKindBoard
          : l10n.materialKindEdge,
      statusIntent: material.isBoard ? StatusIntent.info : StatusIntent.warning,
      leading: Icon(
        material.isBoard ? AppIcons.board : AppIcons.edge,
        size: AppIconSize.normal,
        color: theme.colorScheme.primary,
      ),
      metadata: metadata,
    );
  }
}
