import 'package:flutter/material.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Asks for a decision that cannot be taken back, and nothing else.
///
/// A dialog is the most expensive interruption the app has: it blocks, it
/// steals focus, and it must be dismissed before anything else can happen.
/// That is worth it only when proceeding would destroy something. Everything
/// reversible gets a snackbar with an undo instead — see `AppFeedback` — and
/// everything merely optional gets a bottom sheet.
///
/// The shape is fixed here rather than at each call site so the rules in
/// `docs/design_system.md` §8 are structural rather than advisory: a title, at
/// most two actions, cancel on the left and confirm on the right, and a
/// destructive confirm that looks destructive. The one hand-built dialog this
/// replaced had no title and an ordinary-looking confirm button.
///
/// Returns `true` only on an explicit confirm. Dismissing by tapping outside
/// or by the back gesture returns `false`, never `null`, so callers cannot
/// accidentally treat a dismissal as a yes.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);

      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
