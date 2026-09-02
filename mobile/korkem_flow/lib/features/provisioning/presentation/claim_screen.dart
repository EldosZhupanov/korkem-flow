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
import 'package:korkem_flow/features/provisioning/data/provisioning_repository.dart';
import 'package:korkem_flow/features/provisioning/domain/provisioning_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// First-run setup wizard: claims an unconfigured node, creates the initial
/// company and the factory owner account.
class ClaimScreen extends ConsumerStatefulWidget {
  const ClaimScreen({this.serverUrl = '', super.key});

  final String serverUrl;

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _server;
  final _code = TextEditingController();
  final _company = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String _language = 'ru';
  bool _obscuredPassword = true;
  bool _obscuredConfirm = true;
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(
      text: widget.serverUrl.isNotEmpty
          ? widget.serverUrl
          : (ref.read(sessionProvider).value?.serverUrl ?? ''),
    );
  }

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    _company.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final serverUrl = _server.text.trim();
    final email = _ownerEmail.text.trim();
    final password = _password.text;

    try {
      await ref
          .read(provisioningRepositoryProvider)
          .claim(
            baseUrl: serverUrl,
            code: _code.text,
            company: _company.text,
            ownerEmail: email,
            ownerName: _ownerName.text,
            ownerPassword: password,
            language: _language,
          );

      // Immediately sign in as the created owner without asking for the
      // password a second time.
      await ref
          .read(sessionProvider.notifier)
          .signIn(
            serverUrl: serverUrl,
            user: email,
            password: password,
          );
      // On success the router's redirect takes over; this screen is disposed.
    } on ClaimAlreadyClaimedException {
      if (mounted) setState(() => _failure = l10n.claimAlreadyClaimed);
    } on ClaimCodeRefusedException {
      if (mounted) setState(() => _failure = l10n.claimCodeRefused);
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
      appBar: AppBar(
        title: Text(l10n.claimTitle),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: AppLogo(
                        layout: LogoLayout.lockup,
                        size: _lockupWidth,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.claimSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Server URL
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

                    // Launch Code: 16 characters from node log
                    TextFormField(
                      controller: _code,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.5,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.claimCode,
                        hintText: l10n.claimCodeHint,
                        helperText: l10n.claimCodeHelper,
                        helperMaxLines: 2,
                        prefixIcon: const Icon(AppIcons.noAccess),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Company Name
                    TextFormField(
                      controller: _company,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.claimCompany,
                        prefixIcon: const Icon(AppIcons.customer),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Owner Name
                    TextFormField(
                      controller: _ownerName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.claimOwnerName,
                        prefixIcon: const Icon(AppIcons.profile),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Owner Email
                    TextFormField(
                      controller: _ownerEmail,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.claimOwnerEmail,
                        prefixIcon: const Icon(AppIcons.email),
                      ),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Owner Password
                    TextFormField(
                      controller: _password,
                      obscureText: _obscuredPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: l10n.claimOwnerPassword,
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
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Confirm Password (mandatory master owner password
                    // confirmation)
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscuredConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.claimConfirmPassword,
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
                      validator: (value) {
                        final req = _required(value, l10n);
                        if (req != null) return req;
                        if (value != _password.text) {
                          return l10n.claimPasswordMismatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Language Selector
                    Text(
                      l10n.claimLanguage,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'ru',
                          label: Text(l10n.claimLangRu),
                        ),
                        ButtonSegment(
                          value: 'kk',
                          label: Text(l10n.claimLangKk),
                        ),
                        ButtonSegment(
                          value: 'en',
                          label: Text(l10n.claimLangEn),
                        ),
                      ],
                      selected: {_language},
                      onSelectionChanged: (selected) {
                        setState(() => _language = selected.first);
                      },
                    ),

                    // Error banner animated
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
                                child: _FailureBanner(message: _failure!),
                              ),
                            ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const AppBusyIndicator()
                          : Text(l10n.claimSubmit),
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
