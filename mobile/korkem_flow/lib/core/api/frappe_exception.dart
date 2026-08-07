import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

/// Domain-level failure taxonomy.
///
/// Frappe reports business-rule violations as HTTP 417 with a
/// `_server_messages` payload carrying the human-readable text. Parsing that
/// properly is what
/// separates a professional Frappe client from one that shows raw JSON to a
/// factory worker. See docs/mobile_architecture.md §11.
sealed class FrappeException implements Exception {
  const FrappeException(this.message, {this.code});

  /// Maps a transport error onto the taxonomy.
  factory FrappeException.fromDio(DioException error) {
    final status = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkFailure('No connection to the server.');
    }

    final data = error.response?.data;
    final serverMessage = _extractServerMessage(data);
    final code = _extractCode(data);

    return switch (status) {
      401 => const AuthFailure('Your session has expired.'),
      403 => PermissionFailure(
        serverMessage ?? "You don't have access to this.",
        code: code,
      ),
      404 => NotFoundFailure(serverMessage ?? 'Not found.'),
      409 => ConflictFailure(
        serverMessage ?? 'This record changed while you were editing it.',
      ),
      417 || 400 => ValidationFailure(
        serverMessage ?? 'That could not be saved.',
        code: code,
      ),
      _ => ServerFailure(serverMessage ?? 'Something went wrong.', code: code),
    };
  }

  final String message;

  /// A machine-readable reason, when the endpoint supplies one.
  ///
  /// Frappe's own errors carry only a sentence, which is unusable in an
  /// interface that has to speak three languages. Endpoints that need the
  /// client to *act* on the failure — currently the AI gateway — add
  /// `ai_error_code`, and this carries it up so a caller can branch on the
  /// reason rather than parsing English.
  final String? code;

  @override
  String toString() => message;

  static String? _extractCode(Object? data) {
    if (data is! Map) return null;
    final code = data['ai_error_code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// `_server_messages` is a JSON **string** containing a JSON array of JSON
  /// strings. Frappe does not flatten it, so it needs decoding twice.
  static String? _extractServerMessage(Object? data) {
    if (data is! Map) return null;

    final raw = data['_server_messages'];
    if (raw is! String || raw.isEmpty) {
      final exc = data['exception'];
      return exc is String && exc.isNotEmpty ? exc : null;
    }

    try {
      final outer = jsonDecode(raw);
      if (outer is! List || outer.isEmpty) return null;

      final messages = <String>[];
      for (final entry in outer) {
        if (entry is! String) continue;
        try {
          final inner = jsonDecode(entry);
          if (inner is Map && inner['message'] is String) {
            messages.add(_stripHtml(inner['message'] as String));
          }
        } on FormatException {
          messages.add(_stripHtml(entry));
        }
      }
      return messages.isEmpty ? null : messages.join('\n');
    } on FormatException {
      return null;
    }
  }

  static String _stripHtml(String input) =>
      input.replaceAll(RegExp('<[^>]*>'), '').trim();
}

@immutable
final class NetworkFailure extends FrappeException {
  const NetworkFailure(super.message);
}

@immutable
final class AuthFailure extends FrappeException {
  const AuthFailure(super.message);
}

@immutable
final class PermissionFailure extends FrappeException {
  const PermissionFailure(super.message, {super.code});
}

@immutable
final class NotFoundFailure extends FrappeException {
  const NotFoundFailure(super.message);
}

@immutable
final class ConflictFailure extends FrappeException {
  const ConflictFailure(super.message);
}

@immutable
final class ValidationFailure extends FrappeException {
  const ValidationFailure(super.message, {super.code});
}

@immutable
final class ServerFailure extends FrappeException {
  const ServerFailure(super.message, {super.code});
}
