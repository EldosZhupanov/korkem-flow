import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

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

  /// Prefetches roughly one viewport ahead, so the next page is usually already
  /// present by the time the user reaches the bottom.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(dealsControllerProvider.notifier).loadMore());
    }
  }

  Future<void> _openFilter() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showFilterSheet<DealStatus>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(dealFilterProvider).status,
      options: [
        for (final status in DealStatus.values)
          FilterOption(value: status, label: status.wireValue),
      ],
    );

    if (!mounted || choice == null) return;
    ref.read(dealFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dealsControllerProvider);
    final filter = ref.watch(dealFilterProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.status != null,
              child: const Icon(AppIcons.filter),
            ),
            tooltip: l10n.actionFilter,
            onPressed: _openFilter,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppSearchField(
              initialValue: filter.search,
              onChanged: (value) => ref
                  .read(dealFilterProvider.notifier)
                  .setSearch(value.isEmpty ? null : value),
            ),
          ),
        ),
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
            icon: AppIcons.deal,
            message: filter.search != null
                ? l10n.searchNoResults(filter.search!)
                : null,
            actionLabel: filter.status == null && filter.search == null
                ? null
                : l10n.actionClearFilter,
            onAction: filter.status == null && filter.search == null
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

/// A deal rendered with the shared [EntityCard] shape.
class DealCard extends StatelessWidget {
  const DealCard({required this.deal, this.onTap, super.key});

  final Deal deal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EntityCard(
      title: deal.organization,
      subtitle: deal.nextStep,
      statusLabel: deal.status.wireValue,
      statusIntent: intentFor(deal.status),
      onTap: onTap,
      metadata: [
        if (deal.mobileNo != null)
          EntityMeta(icon: AppIcons.call, label: deal.mobileNo!),
      ],
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
