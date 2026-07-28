import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's single source of "now".
typedef Now = DateTime Function();

/// Injected rather than calling [DateTime.now] at the point of use.
///
/// Anything that buckets by time — overdue / today / upcoming — is otherwise
/// impossible to render deterministically, which makes both golden files and
/// boundary tests ("due at 23:59:59 today") unwritable. Production reads the
/// real clock; tests override this with a fixed instant.
final clockProvider = Provider<Now>((ref) => DateTime.now);
