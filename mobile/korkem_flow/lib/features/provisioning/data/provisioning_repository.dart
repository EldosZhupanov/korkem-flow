import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/features/provisioning/domain/provisioning_models.dart';

final provisioningRepositoryProvider = Provider<ProvisioningRepository>((ref) {
  return ProvisioningRepository(ref.watch(authDioProvider));
});

/// Communicates with unauthenticated node provisioning endpoints.
///
/// Both `status` and `claim` are called before any credentials exist, so
/// requests go through an unauthenticated [Dio] client directly.
class ProvisioningRepository {
  ProvisioningRepository(this._dio);

  final Dio _dio;

  static const _statusPath =
      '/api/method/korkem_manufacturing.api.provisioning.status';
  static const _claimPath =
      '/api/method/korkem_manufacturing.api.provisioning.claim';

  /// Asks whether the node at [baseUrl] already has an owner.
  Future<ProvisioningStatus> checkStatus(String baseUrl) async {
    final normalised = normaliseServerUrl(baseUrl);
    if (normalised.isEmpty) {
      return const ProvisioningStatus(
        claimed: true,
        languages: ['ru', 'kk', 'en'],
      );
    }

    try {
      final uri = Uri.parse(normalised).resolve(_statusPath);
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final message = response.data?['message'];
      if (message is Map<String, dynamic>) {
        return ProvisioningStatus.fromJson(message);
      }
      if (response.data is Map<String, dynamic>) {
        return ProvisioningStatus.fromJson(response.data!);
      }
      return const ProvisioningStatus(
        claimed: true,
        languages: ['ru', 'kk', 'en'],
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const ProvisioningStatus(
          claimed: true,
          languages: ['ru', 'kk', 'en'],
        );
      }
      throw FrappeException.fromDio(error);
    }
  }

  /// Claims an unconfigured node and creates the initial company and owner.
  Future<ClaimResult> claim({
    required String baseUrl,
    required String code,
    required String company,
    required String ownerEmail,
    required String ownerName,
    required String ownerPassword,
    String country = 'Kazakhstan',
    String currency = 'KZT',
    String timezone = 'Asia/Almaty',
    String language = 'ru',
  }) async {
    final normalised = normaliseServerUrl(baseUrl);
    final cleanCode = code.replaceAll(RegExp(r'\s+'), '').trim();

    try {
      final uri = Uri.parse(normalised).resolve(_claimPath);
      final response = await _dio.postUri<Map<String, dynamic>>(
        uri,
        data: {
          'code': cleanCode,
          'company': company.trim(),
          'owner_email': ownerEmail.trim(),
          'owner_name': ownerName.trim(),
          'owner_password': ownerPassword,
          'country': country,
          'currency': currency,
          'timezone': timezone,
          'language': language,
        },
      );

      final message = response.data?['message'];
      if (message is Map<String, dynamic>) {
        final status = message['status'] as String?;
        if (status == 'already_claimed') {
          throw const ClaimAlreadyClaimedException();
        }
        if (status == 'code_refused') {
          throw const ClaimCodeRefusedException();
        }
        return ClaimResult.fromJson(message);
      }
      if (response.data is Map<String, dynamic>) {
        final status = response.data!['status'] as String?;
        if (status == 'already_claimed') {
          throw const ClaimAlreadyClaimedException();
        }
        if (status == 'code_refused') {
          throw const ClaimCodeRefusedException();
        }
        return ClaimResult.fromJson(response.data!);
      }
      throw const ServerFailure('Invalid response from server');
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      if (statusCode == 409) {
        throw const ClaimAlreadyClaimedException();
      }
      if (statusCode == 403) {
        throw const ClaimCodeRefusedException();
      }

      if (data is Map) {
        final msg = data['message'];
        if (msg is Map) {
          final status = msg['status'];
          if (status == 'already_claimed') {
            throw const ClaimAlreadyClaimedException();
          }
          if (status == 'code_refused') {
            throw const ClaimCodeRefusedException();
          }
        }
        final status = data['status'];
        if (status == 'already_claimed') {
          throw const ClaimAlreadyClaimedException();
        }
        if (status == 'code_refused') {
          throw const ClaimCodeRefusedException();
        }
      }

      throw FrappeException.fromDio(error);
    }
  }
}
