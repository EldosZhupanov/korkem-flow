import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/company_details/domain/company_details.dart';

final companyDetailsRepositoryProvider = Provider<CompanyDetailsRepository>((
  ref,
) {
  return CompanyDetailsRepository(ref.watch(frappeClientProvider));
});

/// Data access for company legal addresses, BIN, and banking information.
class CompanyDetailsRepository {
  const CompanyDetailsRepository(this._client);

  static const _base = 'korkem_manufacturing.api.company_details';
  static const readEndpoint = '$_base.read';
  static const saveEndpoint = '$_base.save';

  final FrappeClient _client;

  /// Реквизиты, записанные сейчас.
  Future<CompanyDetails> fetch() async {
    return _parsed(
      await _client.callMethod(readEndpoint),
      'Сервер не вернул реквизиты компании.',
    );
  }

  /// Saves the company details.
  ///
  /// Empty fields are not sent so that the server retains stored values.
  Future<CompanyDetails> save(CompanyDetails details) async {
    final response = await _client.callMethod(
      saveEndpoint,
      post: true,
      params: {
        if (details.bin.isNotEmpty) 'bin': details.bin,
        if (details.phone.isNotEmpty) 'phone': details.phone,
        if (details.email.isNotEmpty) 'email': details.email,
        if (details.website.isNotEmpty) 'website': details.website,
        if (details.address.isNotEmpty) 'address': details.address,
        if (details.city.isNotEmpty) 'city': details.city,
        if (details.bankName.isNotEmpty) 'bank_name': details.bankName,
        if (details.bankAccount.isNotEmpty) 'bank_account': details.bankAccount,
        if (details.bik.isNotEmpty) 'bik': details.bik,
      },
    );
    // То, что записалось, приходит от сервера — им и отвечаем. Вернуть здесь
    // отправленное значило бы показать владельцу его же ввод как сохранённый,
    // хотя мы не знаем, что сервер с ним сделал: IBAN он переписывает без
    // пробелов, а не присланное поле оставляет прежним.
    return _parsed(
      response,
      'Сервер принял реквизиты, но не сказал, что записал. Откройте экран '
      'заново и проверьте.',
    );
  }

  CompanyDetails _parsed(Map<String, dynamic> response, String whenMissing) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map || raw.isEmpty) {
      throw ServerFailure(whenMissing);
    }
    return CompanyDetails.fromJson(Map<String, dynamic>.from(raw));
  }
}
