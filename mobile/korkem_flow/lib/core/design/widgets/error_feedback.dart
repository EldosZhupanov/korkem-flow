import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The sentence to put in front of a user for [error].
///
/// [FrappeException] already carries the human text — Frappe hides business
/// rule violations inside `_server_messages` and the client decodes them — so
/// interpolating one is correct and says what the backend meant.
///
/// Anything else is a defect in this app: a `TypeError`, a `FormatException`,
/// a failed null check. Interpolating *those* puts a Dart type name in front
/// of a factory worker, which tells them nothing and looks broken. They get a
/// sentence instead; the detail belongs in the log, not on the shop floor.
///
/// Deliberately a plain function on values rather than a widget or a
/// context-taking helper. Every caller reaches it *after* an `await`, where the
/// element may already be gone — so each one captures its messenger and its
/// localisations before the gap, and needs something it can call with those
/// rather than something that goes looking for a `BuildContext`.
String errorMessageOf(Object error, AppLocalizations l10n) =>
    error is FrappeException ? error.message : l10n.errorGeneric;
