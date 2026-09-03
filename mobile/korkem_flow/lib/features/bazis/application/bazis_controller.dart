import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/bazis/data/bazis_repository.dart';
import 'package:korkem_flow/features/bazis/domain/bazis_models.dart';

@immutable
class BazisScreenState {
  const BazisScreenState({
    this.filename,
    this.fileBytes,
    this.isInspecting = false,
    this.inspectResult,
    this.inspectError,
    this.isImporting = false,
    this.importResult,
    this.importError,
    this.salesOrder,
  });

  final String? filename;
  final List<int>? fileBytes;
  final bool isInspecting;
  final BazisInspectResult? inspectResult;
  final String? inspectError;
  final bool isImporting;
  final BazisImportResult? importResult;
  final String? importError;
  final String? salesOrder;

  bool get hasFile => filename != null && fileBytes != null;
  bool get isInspected => inspectResult != null;
  bool get isImported => importResult != null;

  BazisScreenState copyWith({
    String? filename,
    List<int>? fileBytes,
    bool? isInspecting,
    BazisInspectResult? inspectResult,
    String? inspectError,
    bool? isImporting,
    BazisImportResult? importResult,
    String? importError,
    String? salesOrder,
    bool clearInspectResult = false,
    bool clearImportResult = false,
    bool clearErrors = false,
  }) {
    return BazisScreenState(
      filename: filename ?? this.filename,
      fileBytes: fileBytes ?? this.fileBytes,
      isInspecting: isInspecting ?? this.isInspecting,
      inspectResult: clearInspectResult
          ? null
          : (inspectResult ?? this.inspectResult),
      inspectError: clearErrors ? null : (inspectError ?? this.inspectError),
      isImporting: isImporting ?? this.isImporting,
      importResult: clearImportResult
          ? null
          : (importResult ?? this.importResult),
      importError: clearErrors ? null : (importError ?? this.importError),
      salesOrder: salesOrder ?? this.salesOrder,
    );
  }
}

class BazisController extends Notifier<BazisScreenState> {
  @override
  BazisScreenState build() {
    return const BazisScreenState();
  }

  BazisRepository get _repository => ref.read(bazisRepositoryProvider);

  /// Sets the associated sales order reference if opened from an order.
  void setSalesOrder(String? salesOrder) {
    if (state.salesOrder != salesOrder) {
      state = state.copyWith(salesOrder: salesOrder);
    }
  }

  /// Loads the picked file and immediately inspects it.
  Future<void> loadFile({
    required String filename,
    required List<int> bytes,
  }) async {
    state = state.copyWith(
      filename: filename,
      fileBytes: bytes,
      isInspecting: true,
      clearInspectResult: true,
      clearImportResult: true,
      clearErrors: true,
    );

    try {
      final result = await _repository.inspectSpecification(
        filename: filename,
        bytes: bytes,
      );
      state = state.copyWith(
        isInspecting: false,
        inspectResult: result,
      );
    } on FrappeException catch (e) {
      state = state.copyWith(
        isInspecting: false,
        inspectError: e.message,
      );
    } on Object catch (e) {
      state = state.copyWith(
        isInspecting: false,
        inspectError: '$e',
      );
    }
  }

  /// Imports the inspected specification into ERPNext.
  Future<void> importSpecification() async {
    final filename = state.filename;
    final bytes = state.fileBytes;
    if (filename == null || bytes == null) return;

    state = state.copyWith(
      isImporting: true,
      clearImportResult: true,
      clearErrors: true,
    );

    try {
      final result = await _repository.importSpecification(
        filename: filename,
        bytes: bytes,
        salesOrder: state.salesOrder,
      );
      state = state.copyWith(
        isImporting: false,
        importResult: result,
      );
    } on FrappeException catch (e) {
      state = state.copyWith(
        isImporting: false,
        importError: e.message,
      );
    } on Object catch (e) {
      state = state.copyWith(
        isImporting: false,
        importError: '$e',
      );
    }
  }

  void reset() {
    state = BazisScreenState(salesOrder: state.salesOrder);
  }
}

// AutoDisposeNotifierProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final bazisControllerProvider =
    NotifierProvider.autoDispose<BazisController, BazisScreenState>(
      BazisController.new,
    );
