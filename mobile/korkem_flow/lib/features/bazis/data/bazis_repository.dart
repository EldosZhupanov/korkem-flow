import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/bazis/domain/bazis_models.dart';

final bazisRepositoryProvider = Provider<BazisRepository>((ref) {
  return BazisRepository(ref.watch(frappeClientProvider));
});

/// Repository for reading and importing Bazis-Mebelschik XML specifications.
class BazisRepository {
  BazisRepository(this._client);

  final FrappeClient _client;

  static const inspectEndpoint = 'korkem_manufacturing.api.bazis.inspect';
  static const importEndpoint =
      'korkem_manufacturing.api.bazis.import_specification';

  /// Inspects a Bazis XML export without writing anything to the database.
  ///
  /// Tells the technologist what is in the file (products, parts, materials,
  /// operations).
  Future<BazisInspectResult> inspectSpecification({
    required String filename,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const ValidationFailure('Пустой файл.');
    }

    final response = await _client.uploadFile(
      inspectEndpoint,
      field: 'file',
      filename: filename,
      bytes: bytes,
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to inspect Bazis specification: '
        'unexpected response from server.',
      );
    }

    return BazisInspectResult.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Creates item records, BOM draft, and routing from the Bazis XML export.
  Future<BazisImportResult> importSpecification({
    required String filename,
    required List<int> bytes,
    String? salesOrder,
  }) async {
    if (bytes.isEmpty) {
      throw const ValidationFailure('Пустой файл.');
    }

    final fields = <String, dynamic>{
      if (salesOrder != null && salesOrder.trim().isNotEmpty)
        'sales_order': salesOrder.trim(),
    };

    final response = await _client.uploadFile(
      importEndpoint,
      field: 'file',
      filename: filename,
      bytes: bytes,
      fields: fields,
    );

    final dynamic raw = response['message'] ?? response['data'];
    if (raw == null || raw is! Map || raw.isEmpty) {
      throw const ServerFailure(
        'Failed to import Bazis specification: '
        'unexpected response from server.',
      );
    }

    return BazisImportResult.fromJson(Map<String, dynamic>.from(raw));
  }
}
