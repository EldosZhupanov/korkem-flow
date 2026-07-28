import 'package:dio/dio.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';

/// Signs in against a Frappe site and mints the strongest credential the user's
/// roles allow.
///
/// Deliberately takes a raw [Dio] rather than the app's `FrappeClient`: sign-in
/// happens *before* any credential exists, so it must not travel through the
/// interceptor that attaches one.
class AuthRepository {
  const AuthRepository(this._dio);

  static const _loginPath = '/api/method/login';
  static const _logoutPath = '/api/method/logout';
  static const _generateKeysPath =
      '/api/method/frappe.core.doctype.user.user.generate_keys';
  static const _whoAmIPath = '/api/method/frappe.auth.get_logged_user';

  final Dio _dio;

  /// Exchanges a password for a durable credential.
  ///
  /// Two round trips, and the second is allowed to fail: `generate_keys` is
  /// restricted to System Managers, so most real users legitimately end up on
  /// the session-cookie path. That is a successful sign-in, not a degraded one.
  Future<AuthCredentials> signIn({
    required String baseUrl,
    required String user,
    required String password,
  }) async {
    final sid = await _openSession(
      baseUrl: baseUrl,
      user: user,
      password: password,
    );

    // The login response carries a display name, not the canonical user id.
    // Asking the server avoids storing whatever casing the user typed.
    final resolvedUser = await _whoAmI(baseUrl: baseUrl, sid: sid) ?? user;

    final keys = await _tryGenerateKeys(
      baseUrl: baseUrl,
      sid: sid,
      user: resolvedUser,
    );

    return keys ?? SessionCredentials(user: resolvedUser, sid: sid);
  }

  /// Confirms a stored credential still works, returning its owner.
  ///
  /// Called on launch. A session cookie can expire server-side with nothing to
  /// signal it locally, so the only honest check is to ask.
  Future<String> verify({
    required String baseUrl,
    required AuthCredentials credentials,
  }) async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _uri(baseUrl, _whoAmIPath),
        options: Options(headers: Map.fromEntries([credentials.header])),
      );
      final user = response.data?['message'];
      if (user is! String || user.isEmpty || user == 'Guest') {
        throw const AuthFailure('Your session has expired.');
      }
      return user;
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Best-effort server-side teardown. The local credential is dropped either
  /// way — a user who taps "sign out" must end up signed out even offline.
  Future<void> signOut({
    required String baseUrl,
    required AuthCredentials credentials,
  }) async {
    try {
      await _dio.getUri<dynamic>(
        _uri(baseUrl, _logoutPath),
        options: Options(headers: Map.fromEntries([credentials.header])),
      );
    } on DioException {
      // Intentionally swallowed; see the doc comment.
    }
  }

  Future<String> _openSession({
    required String baseUrl,
    required String user,
    required String password,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.postUri<dynamic>(
        _uri(baseUrl, _loginPath),
        data: {'usr': user, 'pwd': password},
      );
    } on DioException catch (error) {
      // 401 here means "wrong password", not "session expired" — the generic
      // mapping would show the user a message about a session they never had.
      if (error.response?.statusCode == 401) {
        throw const AuthFailure('Incorrect email or password.');
      }
      throw FrappeException.fromDio(error);
    }

    final sid = _sidFrom(response.headers.map['set-cookie']);
    if (sid == null) {
      throw const ServerFailure('The server did not start a session.');
    }
    return sid;
  }

  Future<String?> _whoAmI({
    required String baseUrl,
    required String sid,
  }) async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _uri(baseUrl, _whoAmIPath),
        options: Options(headers: {'Cookie': 'sid=$sid'}),
      );
      final user = response.data?['message'];
      return user is String && user.isNotEmpty ? user : null;
    } on DioException {
      return null;
    }
  }

  Future<ApiKeyCredentials?> _tryGenerateKeys({
    required String baseUrl,
    required String sid,
    required String user,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _generateKeysPath),
        data: {'user': user},
        options: Options(headers: {'Cookie': 'sid=$sid'}),
      );

      final message = response.data?['message'];
      if (message is! Map) return null;

      final apiKey = message['api_key'];
      final apiSecret = message['api_secret'];
      if (apiKey is! String || apiSecret is! String) return null;

      return ApiKeyCredentials(
        user: user,
        apiKey: apiKey,
        apiSecret: apiSecret,
      );
    } on DioException {
      // Any failure here — most often the documented PermissionError for a
      // non-System-Manager — simply means this user stays on the cookie.
      return null;
    }
  }

  /// Frappe sets several cookies; only `sid` authenticates.
  static String? _sidFrom(List<String>? setCookie) {
    for (final cookie in setCookie ?? const <String>[]) {
      for (final part in cookie.split(';')) {
        final trimmed = part.trim();
        if (!trimmed.startsWith('sid=')) continue;
        final value = trimmed.substring(4);
        // A logged-out response also sets `sid=Guest`.
        if (value.isNotEmpty && value != 'Guest') return value;
      }
    }
    return null;
  }

  static Uri _uri(String baseUrl, String path) =>
      Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '') + path);
}
