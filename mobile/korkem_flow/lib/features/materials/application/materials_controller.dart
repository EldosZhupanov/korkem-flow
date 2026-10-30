import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/materials/data/materials_repository.dart';
import 'package:korkem_flow/features/materials/domain/material_item.dart';

@immutable
class MaterialsFilter {
  const MaterialsFilter({
    this.query,
    this.thickness,
    this.colorFamily,
    this.kind,
  });

  final String? query;
  final int? thickness;
  final String? colorFamily;
  final MaterialKind? kind;

  bool get isFiltered =>
      (query != null && query!.trim().isNotEmpty) ||
      thickness != null ||
      (colorFamily != null && colorFamily!.trim().isNotEmpty) ||
      kind != null;

  MaterialsFilter copyWith({
    String? query,
    int? thickness,
    String? colorFamily,
    MaterialKind? kind,
    bool clearQuery = false,
    bool clearThickness = false,
    bool clearColorFamily = false,
    bool clearKind = false,
  }) {
    return MaterialsFilter(
      query: clearQuery ? null : (query ?? this.query),
      thickness: clearThickness ? null : (thickness ?? this.thickness),
      colorFamily: clearColorFamily ? null : (colorFamily ?? this.colorFamily),
      kind: clearKind ? null : (kind ?? this.kind),
    );
  }
}

class MaterialsFilterNotifier extends Notifier<MaterialsFilter> {
  @override
  MaterialsFilter build() => const MaterialsFilter();

  void setQuery(String? query) {
    final trimmed = query?.trim();
    state = state.copyWith(
      query: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearQuery: trimmed == null || trimmed.isEmpty,
    );
  }

  void setThickness(int? thickness) {
    state = state.copyWith(
      thickness: thickness,
      clearThickness: thickness == null,
    );
  }

  void setColorFamily(String? colorFamily) {
    final trimmed = colorFamily?.trim();
    state = state.copyWith(
      colorFamily: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      clearColorFamily: trimmed == null || trimmed.isEmpty,
    );
  }

  void setKind(MaterialKind? kind) {
    state = state.copyWith(
      kind: kind,
      clearKind: kind == null,
    );
  }

  void clear() {
    state = const MaterialsFilter();
  }
}

final materialsFilterProvider =
    NotifierProvider<MaterialsFilterNotifier, MaterialsFilter>(
      MaterialsFilterNotifier.new,
    );

final materialsControllerProvider =
    AsyncNotifierProvider<MaterialsController, PagedList<MaterialItem>>(
      MaterialsController.new,
    );

class MaterialsController extends PagedListController<MaterialItem> {
  @override
  int get pageSize => 20;

  @override
  Future<List<MaterialItem>> fetchPage({
    required int offset,
    required int pageSize,
  }) async {
    final filter = ref.watch(materialsFilterProvider);
    final repo = ref.watch(materialsRepositoryProvider);

    final page = await repo.fetchMaterials(
      limit: pageSize,
      offset: offset,
      query: filter.query,
      thickness: filter.thickness,
      colorFamily: filter.colorFamily,
      kind: filter.kind?.name,
    );

    return page.materials;
  }
}
