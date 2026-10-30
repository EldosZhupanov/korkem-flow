import 'package:dio/dio.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';

/// Thin, typed wrapper over Frappe's HTTP surface.
///
/// The backend exposes only three custom whitelisted methods
/// (docs/backend_api_audit.md §3), so this generic client *is* the data layer
/// for almost every screen. It offers exactly four operations, matching the
/// endpoints verified against the running backend.
class FrappeClient {
  FrappeClient(this._dio);

  final Dio _dio;

  /// `GET /api/resource/{doctype}`
  Future<List<Map<String, dynamic>>> getList(
    String doctype,
    FrappeQuery query,
  ) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/api/resource/${Uri.encodeComponent(doctype)}',
        queryParameters: query.toQueryParameters(),
      ),
    );

    final data = response['data'];
    if (data is! List) {
      throw const ServerFailure('Unexpected response shape for a list.');
    }
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// `GET /api/resource/{doctype}/{name}`
  ///
  /// [name] is `Object` because it is not uniformly a String: `CRM Task` uses
  /// `naming_rule: Autoincrement`, so its name is an **integer**.
  Future<Map<String, dynamic>> getDoc(String doctype, Object name) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/api/resource/${Uri.encodeComponent(doctype)}/'
        '${Uri.encodeComponent('$name')}',
      ),
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ServerFailure('Unexpected response shape for a document.');
    }
    return data;
  }

  /// `GET|POST /api/method/{path}`
  Future<Map<String, dynamic>> callMethod(
    String path, {
    Map<String, dynamic>? params,
    bool post = false,
  }) {
    return _send<Map<String, dynamic>>(
      () => post
          ? _dio.post<Map<String, dynamic>>(
              '/api/method/$path',
              data: params,
            )
          : _dio.get<Map<String, dynamic>>(
              '/api/method/$path',
              queryParameters: params,
            ),
    );
  }

  /// `POST /api/method/run_doc_method` — how whitelisted *document* methods are
  /// invoked (e.g. `Pending Action.approve`). Verified live.
  Future<Map<String, dynamic>> runDocMethod(
    String doctype,
    Object name,
    String method, {
    Map<String, dynamic>? args,
  }) {
    return callMethod(
      'run_doc_method',
      post: true,
      params: <String, dynamic>{
        'dt': doctype,
        'dn': '$name',
        'method': method,
        'args': ?args,
      },
    );
  }

  /// `POST /api/method/<path>` с файлом в теле — так снимок с телефона
  /// доходит до сервера. Frappe читает его из `frappe.request.files`.
  ///
  /// Не base64 в JSON: это треть лишнего веса на мобильной сети и снимок
  /// целиком в памяти дважды.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String field,
    required String filename,
    required List<int> bytes,
    Map<String, dynamic> fields = const <String, dynamic>{},
  }) {
    final form = FormData.fromMap(<String, dynamic>{
      ...fields,
      field: MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _send<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>('/api/method/$path', data: form),
    );
  }

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('Empty response from the server.');
      }
      return data;
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }
}
