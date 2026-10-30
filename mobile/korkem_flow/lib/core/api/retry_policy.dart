import 'package:korkem_flow/core/api/frappe_exception.dart';

/// How long to wait before retrying a failed provider, or `null` to give up.
///
/// Riverpod 3 retries a failed provider forever by default, with backoff. The
/// consequence on a device is worse than it sounds: a provider that keeps
/// failing stays in `AsyncLoading`, never reaching `AsyncError`, so the screen
/// shows its loading skeleton indefinitely. Going offline made every screen in
/// the app look permanently frozen — no message, and no way to retry, because
/// the error view that exists was never reached.
///
/// This is not a hypothetical for a factory-floor app on poor Wi-Fi. It is the
/// normal case.
///
/// So: retry twice for a genuine blip, then surface the failure and let the
/// user decide. Every list and detail screen already renders an `ErrorView`
/// with a retry action, and pull-to-refresh works — recovery is one gesture,
/// and an honest error beats a spinner that never ends.
Duration? retryPolicy(int retryCount, Object error) {
  // Waiting does not fix these. The credential is wrong, missing or refused;
  // retrying only delays telling the user something they must act on.
  if (error is AuthFailure ||
      error is PermissionFailure ||
      error is NotFoundFailure ||
      error is ValidationFailure) {
    return null;
  }

  if (retryCount >= _maxAttempts) return null;

  // Short and bounded: long enough to ride out a handover between access
  // points, short enough that a user staring at the screen is not left
  // guessing. Total added delay before the error appears is under a second.
  return Duration(milliseconds: 200 * (retryCount + 1));
}

const _maxAttempts = 2;
