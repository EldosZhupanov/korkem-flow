import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:path_provider/path_provider.dart';

final cncPatternsRepositoryProvider = Provider<CncPatternsRepository>(
  (ref) => CncPatternsRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cncStatusProvider = FutureProvider.autoDispose<CncStatus>(
  (ref) => ref.watch(cncPatternsRepositoryProvider).status(),
);

/// Where the programs are written: a folder the operator finds again.
final cncFileSaverProvider = Provider<CncFileSaver>(
  (ref) => const CncFileSaver(),
);

/// «Узоры ЧПУ» — `korkem_manufacturing.api.cnc_patterns`.
class CncPatternsRepository {
  const CncPatternsRepository(this._client);

  static const _base = 'korkem_manufacturing.api.cnc_patterns';

  final FrappeClient _client;

  Future<CncStatus> status() async =>
      CncStatus.fromJson(_map(await _client.callMethod('$_base.status')));

  Future<CncStatus> _post(String method, Map<String, dynamic> params) async =>
      CncStatus.fromJson(
        _map(
          await _client.callMethod(
            '$_base.$method',
            post: true,
            params: params,
          ),
        ),
      );

  Future<CncStatus> setEnabled({
    required bool enabled,
    List<String>? users,
  }) => _post('set_enabled', {
    'enabled': enabled ? 1 : 0,
    if (users != null) 'users': jsonEncode(users),
  });

  Future<CncStatus> saveTool(CncTool tool, {String? oldName}) =>
      _post('save_tool', {
        'name': tool.name,
        'kind': tool.kind.wire,
        'diameter': tool.diameter,
        'angle': tool.angle,
        'feed': tool.feed,
        'plunge': tool.plunge,
        'rpm': tool.rpm,
        'pass_depth': tool.passDepth,
        if (oldName != null && oldName.isNotEmpty) 'old_name': oldName,
      });

  /// An ArtCAM tool database read: each tool, ready or why not.
  Future<List<ArtcamTool>> artcamPreview(Uint8List file) async {
    final j = _map(
      await _client.callMethod(
        '$_base.artcam_preview',
        post: true,
        params: {'content_b64': base64Encode(file)},
      ),
    );
    return [
      for (final t in j['tools'] is List ? j['tools'] as List : const [])
        if (t is Map) ArtcamTool.fromJson(Map<String, dynamic>.from(t)),
    ];
  }

  /// The picked tools of the file into «Фрезы»; the server reads it again.
  Future<CncStatus> artcamAdd(Uint8List file, List<int> picked) =>
      _post('artcam_add', {
        'content_b64': base64Encode(file),
        'picked': jsonEncode(picked),
      });

  Future<CncStatus> deleteTool(String name) =>
      _post('delete_tool', {'name': name});

  Future<CncStatus> savePattern(CncPattern pattern, {String? oldName}) =>
      _post('save_pattern', {
        'name': pattern.name,
        'elements': jsonEncode([for (final e in pattern.elements) e.toJson()]),
        'milling': pattern.milling ?? '',
        'min_w': pattern.minW.round(),
        'min_h': pattern.minH.round(),
        'fallback': pattern.fallback ?? '',
        if (oldName != null && oldName.isNotEmpty) 'old_name': oldName,
      });

  Future<CncStatus> deletePattern(String name) =>
      _post('delete_pattern', {'name': name});

  Future<CncStatus> setMachine(CncMachine machine) =>
      _post('set_machine', machine.toJson());

  /// The pattern as it stands in the editor, saved or not.
  Future<CncPreview> preview(
    CncPattern pattern, {
    required double width,
    required double height,
  }) async => CncPreview.fromJson(
    _map(
      await _client.callMethod(
        '$_base.preview',
        post: true,
        params: {
          'pattern': jsonEncode({
            'name': pattern.name,
            'milling': pattern.milling,
            'min_w': pattern.minW,
            'min_h': pattern.minH,
            'elements': [for (final e in pattern.elements) e.toJson()],
          }),
          'width': width,
          'height': height,
        },
      ),
    ),
  );

  Future<CncOrderPlan> forOrder(String order) async => CncOrderPlan.fromJson(
    _map(
      await _client.callMethod('$_base.for_order', params: {'order': order}),
    ),
  );

  Future<List<CncFile>> orderFiles(String order, {String? line}) async {
    final m = _map(
      await _client.callMethod(
        '$_base.order_files',
        post: true,
        params: {'order': order, 'line': ?line},
      ),
    );
    final files = m['files'];
    return [
      for (final f in files is List ? files : const [])
        if (f is Map) CncFile.fromJson(Map<String, dynamic>.from(f)),
    ];
  }

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}

/// Writes programs into `Загрузки/KORKEM ЧПУ/{folder}` and opens it.
class CncFileSaver {
  const CncFileSaver();

  /// The folder written to.
  Future<String> save(String folder, Map<String, String> files) async {
    final base =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}KORKEM ЧПУ'
      '${Platform.pathSeparator}${_safe(folder)}',
    );
    await dir.create(recursive: true);
    for (final MapEntry(key: name, value: text) in files.entries) {
      await File(
        '${dir.path}${Platform.pathSeparator}${_safe(name)}',
      ).writeAsString(text);
    }
    return dir.path;
  }

  /// One picture into [folder] — a facade shown to a customer; the folder.
  Future<String> saveBytes(String folder, String name, List<int> bytes) async {
    final base =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}KORKEM ЧПУ'
      '${Platform.pathSeparator}${_safe(folder)}',
    );
    await dir.create(recursive: true);
    await File(
      '${dir.path}${Platform.pathSeparator}${_safe(name)}',
    ).writeAsBytes(bytes);
    return dir.path;
  }

  Future<void> open(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
}
