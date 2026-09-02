import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/production/presentation/complete_operation_button.dart';
import 'package:korkem_flow/features/workstations/data/workstation_repository.dart';
import 'package:korkem_flow/features/workstations/domain/station_operation.dart';
import 'package:korkem_flow/features/workstations/domain/workstation_item.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The Workstations screen: shop-floor queue organized by machine rather
/// than by work order.
///
/// Tailored for machine operators: large touch targets, clear product info,
/// due dates, and direct action to complete operations.
class WorkstationsScreen extends ConsumerStatefulWidget {
  const WorkstationsScreen({this.selectedWorkstation, super.key});

  final String? selectedWorkstation;

  @override
  ConsumerState<WorkstationsScreen> createState() => _WorkstationsScreenState();
}

class _WorkstationsScreenState extends ConsumerState<WorkstationsScreen> {
  String? _selectedWorkstation;

  @override
  void initState() {
    super.initState();
    _selectedWorkstation = widget.selectedWorkstation;
  }

  @override
  void didUpdateWidget(WorkstationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedWorkstation != null &&
        widget.selectedWorkstation != _selectedWorkstation) {
      _selectedWorkstation = widget.selectedWorkstation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide =
        size.width >= AppBreakpoints.medium &&
        size.height >= AppBreakpoints.compact;

    final stationsAsync = ref.watch(workstationsProvider);

    if (isWide &&
        _selectedWorkstation == null &&
        stationsAsync.hasValue &&
        stationsAsync.value!.isNotEmpty) {
      _selectedWorkstation = stationsAsync.value!.first.name;
    }

    if (isWide) {
      return AppScreen(
        title: l10n.workstationsTitle,
        fullWidth: true,
        body: Row(
          children: [
            SizedBox(
              width: AppBreakpoints.listPaneWidth,
              child: _WorkstationsList(
                stationsAsync: stationsAsync,
                selectedWorkstation: _selectedWorkstation,
                isWide: true,
                onSelect: (name) => setState(() => _selectedWorkstation = name),
              ),
            ),
            const VerticalDivider(width: AppStroke.hairline),
            Expanded(
              child: _selectedWorkstation != null
                  ? _StationQueueView(
                      workstation: _selectedWorkstation!,
                      key: ValueKey(_selectedWorkstation),
                    )
                  : Center(
                      child: EmptyView(
                        icon: AppIcons.task,
                        title: l10n.workstationsTitle,
                        message: l10n.workstationsSubtitle,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // Narrow layout
    if (_selectedWorkstation != null) {
      return AppScreen(
        title: _selectedWorkstation!,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.close),
            tooltip: l10n.actionClose,
            onPressed: () => setState(() => _selectedWorkstation = null),
          ),
        ],
        body: _StationQueueView(
          workstation: _selectedWorkstation!,
          key: ValueKey(_selectedWorkstation),
        ),
      );
    }

    return AppScreen(
      title: l10n.workstationsTitle,
      body: _WorkstationsList(
        stationsAsync: stationsAsync,
        selectedWorkstation: _selectedWorkstation,
        isWide: false,
        onSelect: (name) => setState(() => _selectedWorkstation = name),
      ),
    );
  }
}

class _WorkstationsList extends ConsumerWidget {
  const _WorkstationsList({
    required this.stationsAsync,
    required this.selectedWorkstation,
    required this.isWide,
    required this.onSelect,
  });

  final AsyncValue<List<WorkstationItem>> stationsAsync;
  final String? selectedWorkstation;
  final bool isWide;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return switch (stationsAsync) {
      AsyncLoading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(workstationsProvider),
      ),
      AsyncData(:final value) when value.isEmpty => EmptyView(
        icon: AppIcons.workOrder,
        title: l10n.workstationsEmptyTitle,
        message: l10n.workstationsEmptyBody,
        actionLabel: l10n.actionRefresh,
        onAction: () => ref.refresh(workstationsProvider.future),
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => ref.refresh(workstationsProvider.future),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final station = value[index];
            final isSelected = isWide && selectedWorkstation == station.name;

            return AppCard(
              isSelected: isSelected,
              onTap: () => onSelect(station.name),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        StatusChip(
                          label: l10n.workstationWaitingCount(station.waiting),
                          intent: StatusIntent.warning,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.forward,
                    size: AppIconSize.small,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    };
  }
}

class _StationQueueView extends ConsumerWidget {
  const _StationQueueView({required this.workstation, super.key});

  final String workstation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queueAsync = ref.watch(stationQueueProvider(workstation));

    return switch (queueAsync) {
      AsyncLoading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(stationQueueProvider(workstation)),
      ),
      AsyncData(:final value) when value.isEmpty => EmptyView(
        icon: AppIcons.check,
        tone: StateTone.success,
        title: l10n.stationQueueEmptyTitle,
        message: l10n.stationQueueEmptyBody,
        actionLabel: l10n.actionRefresh,
        onAction: () async {
          await Future.wait([
            ref.refresh(stationQueueProvider(workstation).future),
            ref.refresh(workstationsProvider.future),
          ]);
        },
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(stationQueueProvider(workstation).future),
            ref.refresh(workstationsProvider.future),
          ]);
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _StationOperationCard(
            operation: value[index],
            workstation: workstation,
          ),
        ),
      ),
    };
  }
}

class _StationOperationCard extends ConsumerWidget {
  const _StationOperationCard({
    required this.operation,
    required this.workstation,
  });

  final StationOperation operation;
  final String workstation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final opTitle = operation.operation?.isNotEmpty == true
        ? operation.operation!
        : operation.name;

    final itemTitle = operation.itemName?.isNotEmpty == true
        ? operation.itemName!
        : (operation.item ?? '');

    final qtyText = operation.completedQty > 0
        ? '${operation.completedQty.toInt()} / ${operation.orderQty.toInt()} шт'
        : '${operation.orderQty.toInt()} шт';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  opTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (operation.status != null)
                StatusChip(
                  label: operation.status!,
                  intent: StatusIntent.info,
                ),
            ],
          ),
          if (itemTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              itemTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaItem(
                icon: AppIcons.item,
                label: l10n.workstationQtyLabel(qtyText),
              ),
              if (operation.dueOn != null)
                _MetaItem(
                  icon: AppIcons.schedule,
                  label: l10n.workstationDueOn(operation.dueOn!),
                ),
              if (operation.plannedMinutes > 0)
                _MetaItem(
                  icon: AppIcons.task,
                  label: l10n.workstationDuration(
                    operation.plannedMinutes.toInt().toString(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: AppStroke.hairline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  operation.workOrder,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              CompleteOperationButton(
                workOrder: operation.workOrder,
                operation: operation.toWorkOrderOperation(),
                orderQty: operation.orderQty,
                onCompleted: () async {
                  ref
                    ..invalidate(stationQueueProvider(workstation))
                    ..invalidate(workstationsProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppIconSize.dense,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
