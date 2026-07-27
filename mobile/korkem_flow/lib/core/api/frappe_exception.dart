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
  const FrappeException(this.message);

  /// Maps a transport error onto the taxonomy.
  factory FrappeException.fromDio(DioException error) {
    final status = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkFailure('No connection to the server.');
    }

    final serverMessage = _extractServerMessage(error.response?.data);

    return switch (status) {
      401 => const AuthFailure('Your session has expired.'),
      403 => PermissionFailure(
        serverMessage ?? "You don't have access to this.",
      ),
      404 => NotFoundFailure(serverMessage ?? 'Not found.'),
      409 => ConflictFailure(
        serverMessage ?? 'This record changed while you were editing it.',
      ),
      417 || 400 => ValidationFailure(
        serverMessage ?? 'That could not be saved.',
      ),
      _ => ServerFailure(serverMessage ?? 'Something went wrong.'),
    };
  }

  final String message;

  @override
  String toString() => message;

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
  const PermissionFailure(super.message);
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
  const ValidationFailure(super.message);
}

@immutable
final class ServerFailure extends FrappeException {
  const ServerFailure(super.message);
}
