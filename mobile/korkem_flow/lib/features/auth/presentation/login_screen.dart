import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Sign-in against a Frappe site.
///
/// The server address is a first-class field, not a build-time constant: the
/// same binary is installed on a factory floor pointing at production and on a
/// manager's phone pointing at staging.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscured = true;
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    // Pre-filled from the last known server so a re-login after an expired
    // session is two fields, not three.
    _server = TextEditingController(
      text: ref.read(sessionProvider).value?.serverUrl ?? '',
    );
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .signIn(
            serverUrl: _server.text,
            user: _email.text.trim(),
            password: _password.text,
          );
      // On success the router's redirect takes over; this screen is disposed.
    } on FrappeException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              // Caps the form on tablets and desktop; an input stretched to
              // 1200dp is unreadable and looks unfinished.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The logo, not the app's name set in Inter. This is the
                    // first screen anyone sees and the one place the brand has
                    // room to be itself; a serif wordmark rendered as a string
                    // in the UI font was a stand-in for artwork nobody had.
                    const Center(
                      child: AppLogo(
                        layout: LogoLayout.lockup,
                        size: _lockupWidth,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.authSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    TextFormField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authServer,
                        hintText: l10n.authServerHint,
                        prefixIcon: const Icon(AppIcons.settings),
                      ),
                      validator: (value) => _validateServer(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: l10n.authEmail,
                        prefixIcon: const Icon(AppIcons.profile),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscured,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        prefixIcon: const Icon(AppIcons.noAccess),
                        suffixIcon: IconButton(
                          // Labelled, in both states. Unlabelled, a screen
                          // reader announces this as "button" and the one
                          // control on the form that changes what is on screen
                          // becomes the one control nobody can identify.
                          tooltip: _obscured
                              ? l10n.authShowPassword
                              : l10n.authHidePassword,
                          icon: Icon(
                            _obscured ? AppIcons.visible : AppIcons.hidden,
                          ),
                          onPressed: () =>
                              setState(() => _obscured = !_obscured),
                        ),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),

                    // Animated in, and the height animates with it. A banner
                    // that appears instantly shunts the sign-in button down
                    // under a finger already on its way to press it.
                    AnimatedSize(
                      duration: motionOf(context, AppDuration.quick),
                      curve: AppCurves.standard,
                      alignment: Alignment.topCenter,
                      child: _failure == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                              ),
                              child: Entrance(
                                // Keyed on the message: a second, different
                                // failure re-runs the entrance instead of
                                // silently swapping text, so the user sees
                                // that something new happened.
                                key: ValueKey(_failure),
                                child: _FailureBanner(message: _failure!),
                              ),
                            ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      // Sized to the text it replaces so the button does not
                      // resize the moment it is pressed.
                      child: _busy
                          ? const AppBusyIndicator()
                          : Text(l10n.authSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _required(String? value, AppLocalizations l10n) =>
      (value == null || value.trim().isEmpty) ? l10n.authFieldRequired : null;

  static String? _validateServer(String? value, AppLocalizations l10n) {
    final required = _required(value, l10n);
    if (required != null) return required;

    final uri = Uri.tryParse(normaliseServerUrl(value!));
    return (uri == null || uri.host.isEmpty) ? l10n.authInvalidServer : null;
  }
}

/// Sized to the form rather than to the screen, so the lockup sits inside the
/// same column the fields do instead of spanning a tablet edge to edge.
const double _lockupWidth = 240;

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.danger,
            size: AppIconSize.small,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
