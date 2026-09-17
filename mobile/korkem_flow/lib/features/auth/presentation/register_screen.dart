import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Registration screen for new furniture businesses and owners.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;
  final _company = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _obscuredPassword = true;
  bool _obscuredConfirm = true;
  bool _showServerConfig = false;
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final defaultUrl = ref.read(sessionProvider).value?.serverUrl ?? '';
    _server = TextEditingController(
      text: defaultUrl.isNotEmpty
          ? defaultUrl
          : ref.read(appConfigProvider).baseUrl,
    );
  }

  @override
  void dispose() {
    _server.dispose();
    _company.dispose();
    _ownerName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_password.text != _confirmPassword.text) {
      setState(() => _failure = l10n.authPasswordsDoNotMatch);
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    final serverUrl = _server.text.trim().isNotEmpty
        ? _server.text.trim()
        : ref.read(appConfigProvider).baseUrl;
    final email = _email.text.trim();
    final password = _password.text;

    try {
      await ref.read(authRepositoryProvider).register(
        baseUrl: serverUrl,
        companyName: _company.text.trim(),
        ownerName: _ownerName.text.trim(),
        email: email,
        password: password,
      );

      // Upon successful registration, immediately sign in.
      await ref.read(sessionProvider.notifier).signIn(
        serverUrl: serverUrl,
        user: email,
        password: password,
      );
      // On success the router redirects to the assistant.
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: AppLogo(
                        layout: LogoLayout.lockup,
                        size: 220,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.authRegisterSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_showServerConfig) ...[
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
                        validator: (value) => _required(value, l10n),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    TextFormField(
                      controller: _company,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authCompanyName,
                        hintText: l10n.authCompanyNameHint,
                        prefixIcon: const Icon(AppIcons.customer),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _ownerName,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authOwnerName,
                        hintText: l10n.authOwnerNameHint,
                        prefixIcon: const Icon(AppIcons.profile),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.authEmail,
                        prefixIcon: const Icon(AppIcons.email),
                      ),
                      validator: (value) => _validateEmail(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscuredPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        prefixIcon: const Icon(AppIcons.noAccess),
                        suffixIcon: IconButton(
                          tooltip: _obscuredPassword
                              ? l10n.authShowPassword
                              : l10n.authHidePassword,
                          icon: Icon(
                            _obscuredPassword
                                ? AppIcons.visible
                                : AppIcons.hidden,
                          ),
                          onPressed: () => setState(
                            () => _obscuredPassword = !_obscuredPassword,
                          ),
                        ),
                      ),
                      validator: (value) => _validatePassword(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscuredConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.authConfirmPassword,
                        prefixIcon: const Icon(AppIcons.noAccess),
                        suffixIcon: IconButton(
                          tooltip: _obscuredConfirm
                              ? l10n.authShowPassword
                              : l10n.authHidePassword,
                          icon: Icon(
                            _obscuredConfirm
                                ? AppIcons.visible
                                : AppIcons.hidden,
                          ),
                          onPressed: () => setState(
                            () => _obscuredConfirm = !_obscuredConfirm,
                          ),
                        ),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),

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
                                key: ValueKey(_failure),
                                child: _RegisterFailureBanner(
                                  message: _failure!,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const AppBusyIndicator()
                          : Text(l10n.authRegister),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _busy ? null : () => context.pop(),
                      child: Text(l10n.authAlreadyHaveAccount),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton.icon(
                        icon: Icon(
                          _showServerConfig
                              ? AppIcons.hidden
                              : AppIcons.settings,
                          size: AppIconSize.small,
                        ),
                        label: Text(
                          _showServerConfig
                              ? l10n.authHideServer
                              : l10n.authCustomServer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onPressed: () => setState(
                          () => _showServerConfig = !_showServerConfig,
                        ),
                      ),
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

  static String? _validateEmail(String? value, AppLocalizations l10n) {
    final req = _required(value, l10n);
    if (req != null) return req;
    if (!value!.contains('@') || !value.contains('.')) {
      return l10n.authEmail;
    }
    return null;
  }

  static String? _validatePassword(String? value, AppLocalizations l10n) {
    final req = _required(value, l10n);
    if (req != null) return req;
    if (value!.length < 6) return l10n.authPasswordTooShort;
    return null;
  }
}

class _RegisterFailureBanner extends StatelessWidget {
  const _RegisterFailureBanner({required this.message});

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
