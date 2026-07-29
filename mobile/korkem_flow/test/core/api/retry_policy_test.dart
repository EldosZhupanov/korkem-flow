import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/retry_policy.dart';

/// Regression. Riverpod 3 retries forever by default, so a provider that keeps
/// failing sits in `AsyncLoading` and never becomes `AsyncError` — offline, the
/// whole app showed loading skeletons with no message and no way to retry.
void main() {
  group('retryPolicy', () {
    test('retries a network failure, then gives up', () {
      const offline = NetworkFailure('No connection to the server.');

      expect(retryPolicy(0, offline), isNotNull);
      expect(retryPolicy(1, offline), isNotNull);
      // The attempt that matters: without a null here the screen never leaves
      // its skeleton.
      expect(retryPolicy(2, offline), isNull);
      expect(retryPolicy(50, offline), isNull);
    });

    test('backs off between attempts rather than hammering', () {
      const offline = NetworkFailure('offline');

      expect(retryPolicy(1, offline)! > retryPolicy(0, offline)!, isTrue);
      // Bounded: the user should not wait seconds to be told something failed.
      expect(retryPolicy(1, offline)! < const Duration(seconds: 1), isTrue);
    });

    test('never retries a failure that waiting cannot fix', () {
      // Retrying a rejected credential just delays telling the user to act.
      expect(retryPolicy(0, const AuthFailure('expired')), isNull);
      expect(retryPolicy(0, const PermissionFailure('no')), isNull);
      expect(retryPolicy(0, const NotFoundFailure('gone')), isNull);
      expect(retryPolicy(0, const ValidationFailure('bad')), isNull);
    });

    test('retries a server fault, which may be transient', () {
      expect(retryPolicy(0, const ServerFailure('502')), isNotNull);
    });
  });
}
