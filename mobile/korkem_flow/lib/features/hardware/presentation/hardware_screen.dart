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
import 'package:korkem_flow/features/hardware/application/hardware_controller.dart';
import 'package:korkem_flow/features/hardware/domain/hardware_item.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Read-only catalogue of furniture hardware (hinges, runners, handles, etc.)
/// with geometric specifications and installation rules.
class HardwareScreen extends ConsumerWidget {
  const HardwareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(hardwareFilterProvider);
    final controller = ref.read(hardwareControllerProvider.notifier);

    return AppScreen(
      title: l10n.hardwareTitle,
      subtitle: l10n.hardwareSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: () =>
              ref.read(hardwareControllerProvider.notifier).refresh(),
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
              hintText: l10n.hardwareSearchHint,
              recentScope: SearchScope.hardware,
              onChanged: (value) =>
                  ref.read(hardwareFilterProvider.notifier).setQuery(value),
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
                  key: const ValueKey('filter:type:all'),
                  label: Text(l10n.hardwareTypeAll),
                  selected: filter.hardwareType == null,
                  onSelected: (_) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:type:hinge'),
                  avatar: const Icon(
                    AppIcons.hinge,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.hardwareTypeHinge),
                  selected: filter.hardwareType == HardwareType.hinge,
                  onSelected: (selected) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(selected ? HardwareType.hinge : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:type:runner'),
                  avatar: const Icon(
                    AppIcons.runner,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.hardwareTypeRunner),
                  selected: filter.hardwareType == HardwareType.runner,
                  onSelected: (selected) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(selected ? HardwareType.runner : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:type:handle'),
                  avatar: const Icon(
                    AppIcons.handle,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.hardwareTypeHandle),
                  selected: filter.hardwareType == HardwareType.handle,
                  onSelected: (selected) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(selected ? HardwareType.handle : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:type:leg'),
                  avatar: const Icon(
                    AppIcons.hardware,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.hardwareTypeLeg),
                  selected: filter.hardwareType == HardwareType.leg,
                  onSelected: (selected) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(selected ? HardwareType.leg : null),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  key: const ValueKey('filter:type:shelf_support'),
                  avatar: const Icon(
                    AppIcons.hardware,
                    size: AppIconSize.inline,
                  ),
                  label: Text(l10n.hardwareTypeShelfSupport),
                  selected: filter.hardwareType == HardwareType.shelfSupport,
                  onSelected: (selected) => ref
                      .read(hardwareFilterProvider.notifier)
                      .setHardwareType(
                        selected ? HardwareType.shelfSupport : null,
                      ),
                ),
                if (filter.hardwareType == HardwareType.hinge) ...[
                  const SizedBox(width: AppSpacing.md),
                  FilterChip(
                    key: const ValueKey('filter:overlay:all'),
                    label: Text(l10n.hardwareOverlayAll),
                    selected: filter.overlay == null,
                    onSelected: (_) => ref
                        .read(hardwareFilterProvider.notifier)
                        .setOverlay(null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    key: const ValueKey('filter:overlay:full'),
                    label: Text(l10n.hardwareOverlayFull),
                    selected: filter.overlay == HingeOverlay.full,
                    onSelected: (selected) => ref
                        .read(hardwareFilterProvider.notifier)
                        .setOverlay(selected ? HingeOverlay.full : null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    key: const ValueKey('filter:overlay:half'),
                    label: Text(l10n.hardwareOverlayHalf),
                    selected: filter.overlay == HingeOverlay.half,
                    onSelected: (selected) => ref
                        .read(hardwareFilterProvider.notifier)
                        .setOverlay(selected ? HingeOverlay.half : null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    key: const ValueKey('filter:overlay:inset'),
                    label: Text(l10n.hardwareOverlayInset),
                    selected: filter.overlay == HingeOverlay.inset,
                    onSelected: (selected) => ref
                        .read(hardwareFilterProvider.notifier)
                        .setOverlay(selected ? HingeOverlay.inset : null),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: PagedListView<HardwareItem>(
              state: ref.watch(hardwareControllerProvider),
              onRefresh: controller.refresh,
              onLoadMore: controller.loadMore,
              itemBuilder: (context, item) => HardwareCard(
                key: ValueKey('hardware:${item.id}'),
                item: item,
              ),
              emptyView: (context) => ListEmptyView(
                icon: AppIcons.hardware,
                title: filter.isFiltered
                    ? l10n.hardwareEmptyFilteredTitle
                    : l10n.hardwareEmptyTitle,
                message: filter.isFiltered
                    ? l10n.hardwareEmptyFilteredMessage
                    : l10n.hardwareEmptyMessage,
                onRefresh: controller.refresh,
                onClearFilter: filter.isFiltered
                    ? () => ref.read(hardwareFilterProvider.notifier).clear()
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card representing a single hardware item formatted according to its type.
class HardwareCard extends StatelessWidget {
  const HardwareCard({required this.item, super.key});

  final HardwareItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return switch (item.hardwareType) {
      HardwareType.hinge => _buildHingeCard(context, l10n, theme),
      HardwareType.runner => _buildRunnerCard(context, l10n, theme),
      HardwareType.handle => _buildHandleCard(context, l10n, theme),
      HardwareType.leg ||
      HardwareType.shelfSupport ||
      HardwareType.other => _buildGenericHardwareCard(context, l10n, theme),
    };
  }

  Widget _buildHingeCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final overlay = item.overlay;
    final angle = item.formattedOpeningAngle(l10n);
    final cup = item.formattedCup(l10n);
    final softClose = item.formattedSoftClose(l10n);
    final mounting = item.mountingSystem?.localizedLabel(l10n);

    // For hinges, the overlay is an installation rule. We communicate
    // the rule directly in the subtitle so cabinet makers know immediately
    // how the door sits.
    final subtitle = overlay != null
        ? overlay.installationExplanation(l10n)
        : (item.model ?? item.brand);

    final metadata = <EntityMeta>[
      if (overlay != null)
        EntityMeta(
          icon: AppIcons.overlay,
          label: overlay.localizedLabel(l10n),
        ),
      if (angle != null)
        EntityMeta(
          icon: AppIcons.openingAngle,
          label: angle,
        ),
      if (cup != null)
        EntityMeta(
          icon: AppIcons.diameter,
          label: cup,
        ),
      if (mounting != null)
        EntityMeta(
          icon: AppIcons.mounting,
          label: mounting,
        ),
      if (softClose != null)
        EntityMeta(
          icon: AppIcons.softClose,
          label: softClose,
        ),
      if (item.colour != null)
        EntityMeta(
          icon: AppIcons.colour,
          label: item.colour!,
        ),
    ];

    return EntityCard(
      title: item.displayTitle,
      subtitle: subtitle,
      statusLabel: item.hardwareType.localizedKindChip(l10n),
      statusIntent: StatusIntent.info,
      leading: Icon(
        AppIcons.hinge,
        size: AppIconSize.normal,
        color: theme.colorScheme.primary,
      ),
      metadata: metadata,
    );
  }

  Widget _buildRunnerCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final length = item.formattedLength(l10n);
    final load = item.formattedLoad(l10n);
    final softClose = item.formattedSoftClose(l10n);

    final metadata = <EntityMeta>[
      if (length != null)
        EntityMeta(
          icon: AppIcons.dimension,
          label: length,
        ),
      if (load != null)
        EntityMeta(
          icon: AppIcons.load,
          label: load,
        ),
      if (softClose != null)
        EntityMeta(
          icon: AppIcons.softClose,
          label: softClose,
        ),
      if (item.colour != null)
        EntityMeta(
          icon: AppIcons.colour,
          label: item.colour!,
        ),
    ];

    return EntityCard(
      title: item.displayTitle,
      subtitle: item.model ?? item.brand,
      statusLabel: item.hardwareType.localizedKindChip(l10n),
      statusIntent: StatusIntent.info,
      leading: Icon(
        AppIcons.runner,
        size: AppIconSize.normal,
        color: theme.colorScheme.primary,
      ),
      metadata: metadata,
    );
  }

  Widget _buildHandleCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final holeSpacing = item.formattedHoleSpacing(l10n);

    final metadata = <EntityMeta>[
      if (holeSpacing != null)
        EntityMeta(
          icon: AppIcons.dimension,
          label: holeSpacing,
        ),
      if (item.colour != null)
        EntityMeta(
          icon: AppIcons.colour,
          label: item.colour!,
        ),
    ];

    return EntityCard(
      title: item.displayTitle,
      subtitle: item.model ?? item.brand,
      statusLabel: item.hardwareType.localizedKindChip(l10n),
      statusIntent: StatusIntent.neutral,
      leading: Icon(
        AppIcons.handle,
        size: AppIconSize.normal,
        color: theme.colorScheme.primary,
      ),
      metadata: metadata,
    );
  }

  Widget _buildGenericHardwareCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final length = item.formattedLength(l10n);
    final load = item.formattedLoad(l10n);

    final metadata = <EntityMeta>[
      if (length != null)
        EntityMeta(
          icon: AppIcons.dimension,
          label: length,
        ),
      if (load != null)
        EntityMeta(
          icon: AppIcons.load,
          label: load,
        ),
      if (item.colour != null)
        EntityMeta(
          icon: AppIcons.colour,
          label: item.colour!,
        ),
    ];

    return EntityCard(
      title: item.displayTitle,
      subtitle: item.model ?? item.brand,
      statusLabel: item.hardwareType.localizedKindChip(l10n),
      statusIntent: StatusIntent.neutral,
      leading: Icon(
        AppIcons.hardware,
        size: AppIconSize.normal,
        color: theme.colorScheme.primary,
      ),
      metadata: metadata,
    );
  }
}
