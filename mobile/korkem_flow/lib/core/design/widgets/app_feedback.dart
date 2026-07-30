import 'package:flutter/material.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Transient feedback, with the three shapes the app actually has.
///
/// An extension on the *messenger* rather than on `BuildContext`, because every
/// call site reaches this after an `await` — a stage change, a completion, an
/// approval — by which point the element may be gone. Capturing the messenger
/// before the gap is the correct pattern, and a context-taking helper would
/// quietly encourage the incorrect one.
///
/// Each of these replaced a hand-built `SnackBar`, and the hand-built ones had
/// already diverged: some queued behind the previous message, some replaced it,
/// and the undo snackbar was the only one that set its own duration.
extension AppFeedback on ScaffoldMessengerState {
  /// Confirms something happened. No action, nothing to decide.
  void showDone(String message) => _show(SnackBar(content: Text(message)));

  /// Reports a failed action in the backend's own words where it gave any.
  ///
  /// A snackbar rather than a dialog: these are all *attempted* changes, and
  /// the record is still on screen and still correct. The user needs to know
  /// the write did not land, not to be blocked until they acknowledge it.
  void showFailure(Object error, AppLocalizations l10n) =>
      showFailureMessage(errorMessageOf(error, l10n));

  /// A failure the caller has already worded, because it needs framing the
  /// error cannot carry — "couldn't complete the task", said seconds after the
  /// swipe that asked for it, when the bare server sentence would arrive with
  /// no indication of what it was about.
  void showFailureMessage(String message) =>
      _show(SnackBar(content: Text(message)));

  /// Confirms something that can still be taken back.
  ///
  /// [AppDebounce.undo] is both this snackbar's lifetime and the window the
  /// action is held for — they are one value because a button that outlives
  /// the window it controls silently stops working while still on screen.
  void showUndoable({
    required String message,
    required String undoLabel,
    required VoidCallback onUndo,
  }) => _show(
    SnackBar(
      content: Text(message),
      duration: AppDebounce.undo,
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );

  /// One message at a time. Queued snackbars mean the user reads the third one
  /// twelve seconds after the tap that caused it, by which point it is no
  /// longer about anything on screen.
  void _show(SnackBar snack) {
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(snack);
  }
}

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
