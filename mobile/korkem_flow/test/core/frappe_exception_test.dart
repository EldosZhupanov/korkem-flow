import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';

DioException _dio({
  int? status,
  Object? data,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final request = RequestOptions(path: '/api/resource/CRM Deal');
  return DioException(
    requestOptions: request,
    type: type,
    response: status == null
        ? null
        : Response<Object?>(
            requestOptions: request,
            statusCode: status,
            data: data,
          ),
  );
}

/// Builds the exact `_server_messages` shape Frappe emits: a JSON string
/// containing a JSON array of JSON strings.
String _serverMessages(List<String> messages) {
  return jsonEncode(
    messages.map((m) => jsonEncode({'message': m})).toList(),
  );
}

void main() {
  group('status mapping', () {
    test('401 becomes AuthFailure', () {
      expect(FrappeException.fromDio(_dio(status: 401)), isA<AuthFailure>());
    });

    test('403 becomes PermissionFailure', () {
      expect(
        FrappeException.fromDio(_dio(status: 403)),
        isA<PermissionFailure>(),
      );
    });

    test('404 becomes NotFoundFailure', () {
      expect(
        FrappeException.fromDio(_dio(status: 404)),
        isA<NotFoundFailure>(),
      );
    });

    test('409 becomes ConflictFailure', () {
      expect(
        FrappeException.fromDio(_dio(status: 409)),
        isA<ConflictFailure>(),
      );
    });

    test('417 becomes ValidationFailure', () {
      expect(
        FrappeException.fromDio(_dio(status: 417)),
        isA<ValidationFailure>(),
      );
    });

    test('500 becomes ServerFailure', () {
      expect(FrappeException.fromDio(_dio(status: 500)), isA<ServerFailure>());
    });

    test('connection error becomes NetworkFailure regardless of status', () {
      expect(
        FrappeException.fromDio(
          _dio(type: DioExceptionType.connectionError),
        ),
        isA<NetworkFailure>(),
      );
    });
  });

  group('_server_messages extraction', () {
    test('surfaces the human message Frappe intended', () {
      final error = _dio(
        status: 417,
        data: {
          '_server_messages': _serverMessages(['Quantity is required']),
        },
      );

      expect(
        FrappeException.fromDio(error).message,
        'Quantity is required',
      );
    });

    test('joins multiple server messages', () {
      final error = _dio(
        status: 417,
        data: {
          '_server_messages': _serverMessages(['First problem', 'Second one']),
        },
      );

      expect(
        FrappeException.fromDio(error).message,
        'First problem\nSecond one',
      );
    });

    test('strips the HTML Frappe embeds in messages', () {
      final error = _dio(
        status: 417,
        data: {
          '_server_messages': _serverMessages([
            'Deal <b>CRM-001</b> not found',
          ]),
        },
      );

      expect(
        FrappeException.fromDio(error).message,
        'Deal CRM-001 not found',
      );
    });

    test('falls back to a friendly message on malformed payload', () {
      final error = _dio(
        status: 417,
        data: {'_server_messages': 'not-json-at-all'},
      );

      // Must never leak raw junk to a factory worker.
      expect(
        FrappeException.fromDio(error).message,
        'That could not be saved.',
      );
    });

    test('falls back when the body is not a map at all', () {
      final error = _dio(status: 500, data: 'a plain HTML error page');

      expect(FrappeException.fromDio(error).message, 'Something went wrong.');
    });

    test('uses the exception field when _server_messages is absent', () {
      final error = _dio(
        status: 500,
        data: {'exception': 'frappe.exceptions.DoesNotExistError'},
      );

      expect(
        FrappeException.fromDio(error).message,
        'frappe.exceptions.DoesNotExistError',
      );
    });
  });
}
