import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/kiosk_store.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

typedef _Person = ({String user, String fullName});

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final _peopleProvider = FutureProvider.autoDispose<List<_Person>>((ref) async {
  final device = await ref.watch(kioskDeviceProvider.future);
  if (device == null) return const [];
  return ref
      .read(authRepositoryProvider)
      .pinPeople(baseUrl: device.serverUrl, deviceToken: device.token);
});

/// Sign-in on a shop-floor tablet: pick yourself, type your PIN.
///
/// Reachable only on a tablet the administrator registered; elsewhere it says
/// so and offers nothing to type into.
class PinLoginScreen extends ConsumerWidget {
  const PinLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final device = ref.watch(kioskDeviceProvider).value;
    final peopleAsync = ref.watch(_peopleProvider);
    return AppScreen(
      title: device?.label ?? l10n.pinLoginTitle,
      subtitle: l10n.pinLoginSubtitle,
      body: peopleAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(_peopleProvider),
        ),
        data: (people) {
          if (device == null || people.isEmpty) {
            return EmptyView(
              icon: AppIcons.noAccess,
              title: l10n.pinLoginUnavailableTitle,
              message: l10n.pinLoginUnavailableMessage,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final person in people)
                ReadableWidth(
                  child: Card(
                    child: ListTile(
                      key: ValueKey('pinPerson:${person.user}'),
                      leading: const Icon(AppIcons.profile),
                      title: Text(person.fullName),
                      onTap: () => _askPin(context, ref, device, person),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _askPin(
    BuildContext context,
    WidgetRef ref,
    KioskDevice device,
    _Person person,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _PinDialog(device: device, person: person),
  );
}

class _PinDialog extends ConsumerStatefulWidget {
  const _PinDialog({required this.device, required this.person});

  final KioskDevice device;
  final _Person person;

  @override
  ConsumerState<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends ConsumerState<_PinDialog> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pin.text.length < 4 || _busy) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .signInWithPin(
            serverUrl: widget.device.serverUrl,
            deviceToken: widget.device.token,
            user: widget.person.user,
            pin: _pin.text,
          );
      navigator.pop();
    } on FrappeException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _pin.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.person.fullName),
      content: TextField(
        key: const ValueKey('pinField'),
        controller: _pin,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.pinLoginPin,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('pinSubmit'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.authSignIn),
        ),
      ],
    );
  }
}
