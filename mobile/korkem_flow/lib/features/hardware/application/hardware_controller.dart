import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/hardware/data/hardware_repository.dart';
import 'package:korkem_flow/features/hardware/domain/hardware_item.dart';

@immutable
class HardwareFilter {
  const HardwareFilter({
    this.query,
    this.hardwareType,
    this.overlay,
  });

  final String? query;
  final HardwareType? hardwareType;
  final HingeOverlay? overlay;

  bool get isFiltered =>
      (query != null && query!.trim().isNotEmpty) ||
      hardwareType != null ||
      overlay != null;

  HardwareFilter copyWith({
    String? query,
    HardwareType? hardwareType,
    HingeOverlay? overlay,
    bool clearQuery = false,
    bool clearHardwareType = false,
    bool clearOverlay = false,
  }) {
    return HardwareFilter(
      query: clearQuery ? null : (query ?? this.query),
      hardwareType: clearHardwareType
          ? null
          : (hardwareType ?? this.hardwareType),
      overlay: clearOverlay ? null : (overlay ?? this.overlay),
    );
  }
}

class HardwareFilterNotifier extends Notifier<HardwareFilter> {
  @override
  HardwareFilter build() => const HardwareFilter();

  void setQuery(String? query) {
    final trimmed = query?.trim();
    state = state.copyWith(
      query: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearQuery: trimmed == null || trimmed.isEmpty,
    );
  }

  void setHardwareType(HardwareType? type) {
    state = state.copyWith(
      hardwareType: type,
      clearHardwareType: type == null,
      // If switching away from hinges, clear overlay filter since
      // overlay applies to hinges.
      clearOverlay: type != HardwareType.hinge,
    );
  }

  void setOverlay(HingeOverlay? overlay) {
    state = state.copyWith(
      overlay: overlay,
      clearOverlay: overlay == null,
    );
  }

  void clear() {
    state = const HardwareFilter();
  }
}

final hardwareFilterProvider =
    NotifierProvider<HardwareFilterNotifier, HardwareFilter>(
      HardwareFilterNotifier.new,
    );

final hardwareControllerProvider =
    AsyncNotifierProvider<HardwareController, PagedList<HardwareItem>>(
      HardwareController.new,
    );

class HardwareController extends PagedListController<HardwareItem> {
  @override
  int get pageSize => 20;

  @override
  Future<List<HardwareItem>> fetchPage({
    required int offset,
    required int pageSize,
  }) async {
    final filter = ref.watch(hardwareFilterProvider);
    final repo = ref.watch(hardwareRepositoryProvider);

    final page = await repo.fetchHardware(
      limit: pageSize,
      offset: offset,
      query: filter.query,
      hardwareType: filter.hardwareType?.code,
      overlay: filter.overlay?.code,
    );

    return page.hardware;
  }
}
