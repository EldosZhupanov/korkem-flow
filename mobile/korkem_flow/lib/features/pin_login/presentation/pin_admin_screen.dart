import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/kiosk_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/pin_login/data/pin_admin_repository.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final pinHoldersProvider = FutureProvider.autoDispose<List<PinHolder>>(
  (ref) => ref.watch(pinAdminRepositoryProvider).people(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final kioskTabletsProvider = FutureProvider.autoDispose<List<KioskTablet>>(
  (ref) => ref.watch(pinAdminRepositoryProvider).devices(),
);

/// The administrator's PIN screen: which tablets take PINs, who has one.
///
/// Every rule — who may do this, which accounts may never get a PIN, how many
/// guesses — is the server's. This screen carries the administrator's choices
/// to it and shows its answers.
class PinAdminScreen extends ConsumerWidget {
  const PinAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final holders = ref.watch(pinHoldersProvider);
    final tablets = ref.watch(kioskTabletsProvider);
    final thisDevice = ref.watch(kioskDeviceProvider).value;

    return AppScreen(
      title: l10n.pinAdminTitle,
      subtitle: l10n.pinAdminSubtitle,
      body: holders.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(pinHoldersProvider),
        ),
        data: (people) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ReadableWidth(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(l10n.pinAdminTablets),
                    if (thisDevice == null)
                      FilledButton.tonal(
                        key: const ValueKey('pinRegisterTablet'),
                        onPressed: () => _registerThisTablet(context, ref),
                        child: Text(l10n.pinAdminRegisterThis),
                      )
                    else
                      Text(l10n.pinAdminThisIs(thisDevice.label)),
                    for (final tablet in tablets.value ?? const <KioskTablet>[])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tablet.label),
                        subtitle: tablet.enabled
                            ? null
                            : Text(l10n.pinAdminRevoked),
                        trailing: tablet.enabled
                            ? TextButton(
                                onPressed: () =>
                                    _revoke(context, ref, tablet.device),
                                child: Text(l10n.pinAdminRevoke),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ReadableWidth(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(l10n.pinAdminPeople),
                    for (final person in people)
                      ListTile(
                        key: ValueKey('pinHolder:${person.user}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(person.fullName),
                        subtitle: person.locked
                            ? Text(l10n.pinAdminLocked)
                            : null,
                        trailing: IconButton(
                          tooltip: l10n.pinAdminClear,
                          icon: const Icon(AppIcons.delete),
                          onPressed: () => _clear(context, ref, person.user),
                        ),
                        onTap: () => _setPin(context, ref, person.user),
                      ),
                    TextButton.icon(
                      key: const ValueKey('pinAssign'),
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.pinAdminAssign),
                      onPressed: () => _setPin(context, ref, null),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerThisTablet(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final label = await _ask(context, l10n.pinAdminTabletName, digits: false);
    if (label == null || label.isEmpty) return;
    try {
      final result = await ref
          .read(pinAdminRepositoryProvider)
          .registerDevice(label);
      final server = ref.read(sessionProvider).value?.serverUrl ?? '';
      await ref
          .read(kioskStoreProvider)
          .write(
            KioskDevice(serverUrl: server, token: result.token, label: label),
          );
      ref
        ..invalidate(kioskDeviceProvider)
        ..invalidate(kioskTabletsProvider);
      messenger.showDone(l10n.pinAdminRegistered);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(pinAdminRepositoryProvider).revokeDevice(id);
      ref.invalidate(kioskTabletsProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref, String user) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(pinAdminRepositoryProvider).clearPin(user);
      ref.invalidate(pinHoldersProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _setPin(
    BuildContext context,
    WidgetRef ref,
    String? user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    var who = user;
    if (who == null) {
      final members = await ref.read(teamRepositoryProvider).fetchTeamMembers();
      if (!context.mounted) return;
      who = await showDialog<String>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(l10n.pinAdminChoosePerson),
          children: [
            for (final member in members.where((m) => m.enabled && !m.isOwner))
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialog).pop(member.email),
                child: Text(member.fullName),
              ),
          ],
        ),
      );
    }
    if (who == null || !context.mounted) return;
    final pin = await _ask(context, l10n.pinAdminNewPin, digits: true);
    if (pin == null) return;
    try {
      await ref.read(pinAdminRepositoryProvider).setPin(who, pin);
      ref.invalidate(pinHoldersProvider);
      messenger.showDone(l10n.pinAdminPinSet);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<String?> _ask(
    BuildContext context,
    String label, {
    required bool digits,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(label: label, digits: digits),
  );
}

/// Owns its controller, so the field outlives the dialog's closing animation.
class _InputDialog extends StatefulWidget {
  const _InputDialog({required this.label, required this.digits});

  final String label;
  final bool digits;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        key: const ValueKey('pinAdminInput'),
        controller: _controller,
        autofocus: true,
        keyboardType: widget.digits ? TextInputType.number : TextInputType.text,
        maxLength: widget.digits ? 6 : 80,
        inputFormatters: widget.digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : const [],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('pinAdminOk'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}

/// Settings row for the administrator. Absent for everybody else: the server
/// refuses them the PIN list, and the row follows that answer.
class PinAdminTile extends ConsumerWidget {
  const PinAdminTile({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(pinHoldersProvider).value == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        key: const ValueKey('pinAdminSettings'),
        leading: const Icon(AppIcons.noAccess),
        title: Text(l10n.pinAdminTitle),
        subtitle: Text(l10n.pinAdminSubtitle),
        trailing: const Icon(AppIcons.forward),
        onTap: onOpen,
      ),
    );
  }
}
