import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/theme/tokens.dart';
import 'package:korkem_flow/core/widgets/app_state_views.dart';
import 'package:korkem_flow/core/widgets/status_chip.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';

class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key});

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Prefetches one viewport ahead so the next page is usually already there
  /// by the time the user reaches the bottom.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(dealsControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dealsControllerProvider);
    final filter = ref.watch(dealFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deals'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.status != null,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter by stage',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dealsControllerProvider.notifier).refresh(),
        child: switch (state) {
          AsyncLoading() => const ListSkeleton(),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.read(dealsControllerProvider.notifier).refresh(),
          ),
          AsyncData(:final value) when value.deals.isEmpty => EmptyView(
            title: 'No deals',
            message: filter.status == null
                ? 'New deals will appear here as they are created.'
                : 'No deals in this stage right now.',
            icon: Icons.handshake_outlined,
            actionLabel: filter.status == null ? null : 'Clear filter',
            onAction: filter.status == null
                ? null
                : () => ref.read(dealFilterProvider.notifier).clear(),
          ),
          AsyncData(:final value) => _DealList(
            page: value,
            controller: _scrollController,
          ),
        },
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final choice = await showModalBottomSheet<_FilterChoice>(
      context: context,
      builder: (context) => _StatusFilterSheet(
        current: ref.read(dealFilterProvider).status,
      ),
    );

    if (!mounted || choice == null) return;
    ref.read(dealFilterProvider.notifier).setStatus(choice.status);
  }
}

/// Wraps the sheet result so "dismissed" (null) is distinguishable from
/// "chose All stages" (a choice carrying a null status). Using a status value
/// as a sentinel would make that real status unselectable.
@immutable
class _FilterChoice {
  const _FilterChoice(this.status);
  final DealStatus? status;
}

class _DealList extends StatelessWidget {
  const _DealList({required this.page, required this.controller});

  final DealsPage page;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.deals.length + (page.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= page.deals.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return DealCard(deal: page.deals[index]);
      },
    );
  }
}

class DealCard extends StatelessWidget {
  const DealCard({required this.deal, this.onTap, super.key});

  final Deal deal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.organization,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: deal.status.wireValue,
                    intent: intentFor(deal.status),
                  ),
                ],
              ),
              if (deal.nextStep != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  deal.nextStep!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (deal.mobileNo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(deal.mobileNo!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Maps a pipeline stage onto a semantic intent.
  static StatusIntent intentFor(DealStatus status) => switch (status) {
    DealStatus.won => StatusIntent.success,
    DealStatus.lost => StatusIntent.danger,
    DealStatus.negotiation || DealStatus.ready => StatusIntent.warning,
    DealStatus.qualification ||
    DealStatus.demo ||
    DealStatus.proposal => StatusIntent.info,
  };
}

class _StatusFilterSheet extends StatelessWidget {
  const _StatusFilterSheet({this.current});

  final DealStatus? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Filter by stage',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text('All stages'),
            selected: current == null,
            onTap: () => Navigator.of(context).pop(const _FilterChoice(null)),
          ),
          for (final status in DealStatus.values)
            ListTile(
              title: Text(status.wireValue),
              selected: current == status,
              trailing: current == status ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(_FilterChoice(status)),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
