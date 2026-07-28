import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/crm/status_catalog_repository.dart';

/// Wiring only. Kept out of the repository so the data layer stays free of
/// Riverpod — and therefore of Flutter, which is what lets these repositories
/// be exercised against a live backend from a plain `dart run` script.
final statusCatalogRepositoryProvider = Provider<StatusCatalogRepository>(
  (ref) => StatusCatalogRepository(ref.watch(frappeClientProvider)),
);

/// The stages of one doctype, fetched once per session.
///
/// Kept alive deliberately: this changes when an administrator edits settings,
/// not while a user scrolls, and re-fetching it on every screen entry would add
/// a round trip to work that has nothing to do with it.
// ignore: specify_nonobvious_property_types — the generics are right there.
final statusCatalogProvider = FutureProvider.family<StatusCatalog, String>((
  ref,
  doctype,
) async {
  ref.keepAlive();

  try {
    return await ref.watch(statusCatalogRepositoryProvider).fetch(doctype);
  } on PermissionFailure {
    // A role that cannot read the settings doctype can still read records. An
    // empty catalogue degrades to showing raw stage names, which is far better
    // than an error screen over a list the user is allowed to see.
    return StatusCatalog.empty;
  }
});
