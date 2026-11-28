import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';

final sawCuttingRepositoryProvider = Provider<SawCuttingRepository>(
  (ref) => SawCuttingRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final sawSettingsProvider = FutureProvider.autoDispose<SawSettings>(
  (ref) => ref.watch(sawCuttingRepositoryProvider).settings(),
);

typedef JournalQuery = ({JournalFilter filter, String search});

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final sawJournalProvider = FutureProvider.autoDispose
    .family<SawJournal, JournalQuery>(
      (ref, query) => ref.watch(sawCuttingRepositoryProvider).journal(query),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cuttingJobProvider = FutureProvider.autoDispose
    .family<CuttingJob, String>(
      (ref, name) => ref.watch(sawCuttingRepositoryProvider).job(name),
    );

final sawFilePickerProvider = Provider<SawFilePicker>(
  (ref) => const SawFilePicker(),
);

/// A parts list from a file on this computer or phone.
class SawFilePicker {
  const SawFilePicker();

  static const extensions = ['xlsx', 'xls', 'csv', 'txt'];

  Future<({String name, Uint8List bytes})?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) return null;
    final f = files.first;
    return (name: f.name, bytes: await f.readAsBytes());
  }
}

/// `korkem_manufacturing.api.saw_cutting`: the saw, the journal, a job.
class SawCuttingRepository {
  SawCuttingRepository(this._client);

  static const _base = 'korkem_manufacturing.api.saw_cutting';

  final FrappeClient _client;

  Future<SawSettings> settings() async =>
      SawSettings.fromJson(_map(await _client.callMethod('$_base.settings')));

  Future<SawSettings> saveSettings({
    required double kerfMm,
    required double trimMm,
    required double offcutMinLengthMm,
    required double offcutMinWidthMm,
    required FenceSide fence,
    required bool edgeDeduct,
    required List<SawSheet> sheets,
  }) async => SawSettings.fromJson(
    _map(
      await _client.callMethod(
        '$_base.save_settings',
        post: true,
        params: {
          'kerf_mm': kerfMm,
          'trim_mm': trimMm,
          'offcut_min_length_mm': offcutMinLengthMm.round(),
          'offcut_min_width_mm': offcutMinWidthMm.round(),
          'fence_side': fence.name,
          'edge_deduct': edgeDeduct ? 1 : 0,
          'sheets': jsonEncode([for (final s in sheets) s.toJson()]),
        },
      ),
    ),
  );

  Future<SawJournal> journal(JournalQuery query) async => SawJournal.fromJson(
    _map(
      await _client.callMethod(
        '$_base.journal',
        params: {
          if (query.filter != JournalFilter.all) 'status': query.filter.name,
          if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        },
      ),
    ),
  );

  Future<CuttingJob> job(String name) async => CuttingJob.fromJson(
    _map(await _client.callMethod('$_base.job', params: {'name': name})),
  );

  /// Parts from a pasted text or a file — nothing is saved.
  Future<ParsedParts> parse({
    String? text,
    ({String name, Uint8List bytes})? file,
  }) async => ParsedParts.fromJson(
    _map(
      await _client.callMethod(
        '$_base.parse',
        post: true,
        params: {
          'text': ?text,
          if (file != null) ...{
            'content': base64Encode(file.bytes),
            'filename': file.name,
          },
        },
      ),
    ),
  );

  /// The layouts of these parts — nothing is saved.
  Future<SawCalculation> calculate(
    String materialItem,
    List<SawPart> parts,
  ) async => SawCalculation.fromJson(
    _map(
      await _client.callMethod(
        '$_base.calculate',
        post: true,
        params: {
          'material_item': materialItem,
          'parts': jsonEncode([for (final p in parts) p.toJson()]),
        },
      ),
    ),
  );

  Future<CuttingJob> save({
    required String materialItem,
    required List<SawPart> parts,
    String? name,
    List<String> orders = const [],
    String? choice,
  }) async => CuttingJob.fromJson(
    _map(
      await _client.callMethod(
        '$_base.save',
        post: true,
        params: {
          'name': ?name,
          'material_item': materialItem,
          'parts': jsonEncode([for (final p in parts) p.toJson()]),
          'orders': jsonEncode(orders),
          'choice': ?choice,
        },
      ),
    ),
  );

  Future<CuttingJob> check(String name, {bool checked = true}) async =>
      CuttingJob.fromJson(
        _map(
          await _client.callMethod(
            '$_base.check',
            post: true,
            params: {'name': name, 'checked': checked ? 1 : 0},
          ),
        ),
      );

  Future<CuttingJob> sheetDone(
    String name,
    int sheet, {
    bool done = true,
    String? sawnBy,
    String? defects,
  }) async => CuttingJob.fromJson(
    _map(
      await _client.callMethod(
        '$_base.sheet_done',
        post: true,
        params: {
          'name': name,
          'sheet_no': sheet,
          'done': done ? 1 : 0,
          'sawn_by': ?sawnBy,
          'defects': ?defects,
        },
      ),
    ),
  );

  Future<CuttingJob> noteDefect(
    String name,
    int sheet,
    String defects,
  ) async => CuttingJob.fromJson(
    _map(
      await _client.callMethod(
        '$_base.note_defect',
        post: true,
        params: {'name': name, 'sheet_no': sheet, 'defects': defects},
      ),
    ),
  );

  Future<CuttingJob> cancel(String name, String reason) async =>
      CuttingJob.fromJson(
        _map(
          await _client.callMethod(
            '$_base.cancel',
            post: true,
            params: {'name': name, 'reason': reason},
          ),
        ),
      );

  Future<CuttingJob> merge(List<String> names) async => CuttingJob.fromJson(
    _map(
      await _client.callMethod(
        '$_base.merge',
        post: true,
        params: {'names': jsonEncode(names)},
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по раскрою.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
