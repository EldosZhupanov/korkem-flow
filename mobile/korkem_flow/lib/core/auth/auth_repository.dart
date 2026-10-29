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
  static const _registerPath =
      '/api/method/korkem_manufacturing.api.registration.register';
  static const _requestOtpPath =
      '/api/method/korkem_manufacturing.api.registration.request_otp';
  static const _verifyOtpPath =
      '/api/method/korkem_manufacturing.api.registration.verify_otp';
  static const _inviteInfoPath =
      '/api/method/korkem_manufacturing.api.invitations.get_info';
  static const _acceptInvitePath =
      '/api/method/korkem_manufacturing.api.invitations.accept';
  static const _pinPeoplePath =
      '/api/method/korkem_manufacturing.api.pin_login.device_people';
  static const _pinLoginPath =
      '/api/method/korkem_manufacturing.api.pin_login.login';

  final Dio _dio;

  /// Requests a 4-digit OTP code for phone verification.
  Future<Map<String, dynamic>> requestOtp({
    required String baseUrl,
    required String phone,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _requestOtpPath),
        data: {'phone': phone.trim()},
      );
      return (response.data?['message'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Verifies the submitted OTP code.
  Future<Map<String, dynamic>> verifyOtp({
    required String baseUrl,
    required String phone,
    required String code,
    String sessionId = '',
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _verifyOtpPath),
        data: {
          'phone': phone.trim(),
          'code': code.trim(),
          'session_id': sessionId.trim(),
        },
      );
      return (response.data?['message'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Fetches context for an invitation token.
  Future<Map<String, dynamic>> getInvitationInfo({
    required String baseUrl,
    required String token,
  }) async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _uri(baseUrl, '$_inviteInfoPath?token=${Uri.encodeComponent(token)}'),
      );
      return (response.data?['message'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Accepts an invitation, binds to company & role.
  Future<Map<String, dynamic>> acceptInvitation({
    required String baseUrl,
    required String token,
    required String phone,
    required String fullName,
    String email = '',
    String password = '',
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _acceptInvitePath),
        data: {
          'token': token.trim(),
          'phone': phone.trim(),
          'full_name': fullName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      return (response.data?['message'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Registers a new furniture company and its owner account.
  Future<Map<String, dynamic>> register({
    required String baseUrl,
    required String companyName,
    required String ownerName,
    required String email,
    required String password,
    String phone = '',
    String? logoBase64,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _registerPath),
        data: {
          'company_name': companyName.trim(),
          'owner_name': ownerName.trim(),
          'email': email.trim(),
          'password': password,
          'phone': phone.trim(),
          'logo_base64': ?logoBase64,
        },
      );
      final message = response.data?['message'];
      if (message is Map && message['status'] != 'ok') {
        throw AuthFailure(
          message['message'] as String? ?? 'Registration failed.',
        );
      }
      return (message as Map<String, dynamic>?) ?? {};
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Who may sign in on this registered tablet: names only.
  Future<List<({String user, String fullName})>> pinPeople({
    required String baseUrl,
    required String deviceToken,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _uri(baseUrl, _pinPeoplePath),
        data: {'device_token': deviceToken},
      );
      final message = response.data?['message'];
      final people = message is Map ? message['people'] : null;
      return [
        for (final row in people is List ? people : const [])
          if (row is Map)
            (
              user: '${row['user'] ?? ''}',
              fullName: '${row['full_name'] ?? row['user'] ?? ''}',
            ),
      ];
    } on DioException catch (error) {
      throw FrappeException.fromDio(error);
    }
  }

  /// Signs in with a PIN on a registered tablet. The server answers with an
  /// ordinary Frappe session, so the result is a cookie credential — PIN
  /// sign-in never mints API keys.
  Future<AuthCredentials> signInWithPin({
    required String baseUrl,
    required String deviceToken,
    required String user,
    required String pin,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.postUri<dynamic>(
        _uri(baseUrl, _pinLoginPath),
        data: {'device_token': deviceToken, 'user': user, 'pin': pin},
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || status == 429) {
        final failure = FrappeException.fromDio(error);
        throw AuthFailure(failure.message);
      }
      throw FrappeException.fromDio(error);
    }
    final sid = _sidFrom(response.headers.map['set-cookie']);
    if (sid == null) {
      throw const ServerFailure('The server did not start a session.');
    }
    return SessionCredentials(user: user, sid: sid);
  }

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
