import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/company_details/data/company_details_repository.dart';
import 'package:korkem_flow/features/company_details/domain/company_details.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final companyDetailsProvider = FutureProvider.autoDispose<CompanyDetails>((
  ref,
) async {
  final repo = ref.watch(companyDetailsRepositoryProvider);
  return repo.fetch();
});

final companyDetailsControllerProvider =
    AsyncNotifierProvider<CompanyDetailsController, CompanyDetails?>(
      CompanyDetailsController.new,
    );

class CompanyDetailsController extends AsyncNotifier<CompanyDetails?> {
  @override
  Future<CompanyDetails?> build() async => null;

  Future<CompanyDetails> save(CompanyDetails details) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(companyDetailsRepositoryProvider);
      final saved = await repo.save(details);
      state = AsyncValue.data(saved);
      ref.invalidate(companyDetailsProvider);
      return saved;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
