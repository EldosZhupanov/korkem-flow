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
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen for joining an existing furniture company by invitation deep link.
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  final _phoneController = TextEditingController(text: '+7 ');
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _inviteInfo;

  bool _otpSent = false;
  bool _otpVerified = false;
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    _loadInviteInfo();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final baseUrl = ref.read(sessionProvider).value?.serverUrl ??
        ref.read(appConfigProvider).baseUrl;

    try {
      final info = await ref
          .read(authRepositoryProvider)
          .getInvitationInfo(baseUrl: baseUrl, token: widget.token);

      if (mounted) {
        if (info['valid'] != true) {
          setState(() {
            _error = info['error'] as String? ?? 'Приглашение недействительно';
            _loading = false;
          });
        } else {
          setState(() {
            _inviteInfo = info;
            final prefilledPhone = info['phone'] as String?;
            if (prefilledPhone != null && prefilledPhone.isNotEmpty) {
              _phoneController.text = prefilledPhone;
            }
            _loading = false;
          });
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone == '+7') {
      setState(() => _error = 'Укажите номер телефона');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final baseUrl = ref.read(sessionProvider).value?.serverUrl ??
        ref.read(appConfigProvider).baseUrl;

    try {
      final res = await ref
          .read(authRepositoryProvider)
          .requestOtp(baseUrl: baseUrl, phone: phone);

      if (mounted) {
        setState(() {
          _otpSent = true;
          _sessionId = res['session_id'] as String? ?? '';
          final devCode = res['dev_code'] as String?;
          if (devCode != null && devCode.isNotEmpty) {
            _otpController.text = devCode;
          }
          _submitting = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _submitting = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код из SMS');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final baseUrl = ref.read(sessionProvider).value?.serverUrl ??
        ref.read(appConfigProvider).baseUrl;

    try {
      final res = await ref.read(authRepositoryProvider).verifyOtp(
            baseUrl: baseUrl,
            phone: _phoneController.text.trim(),
            code: code,
            sessionId: _sessionId,
          );

      if (mounted) {
        if (res['verified'] == true) {
          setState(() {
            _otpVerified = true;
            _submitting = false;
          });
        } else {
          setState(() {
            _error = 'Неверный код';
            _submitting = false;
          });
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _submitting = false;
        });
      }
    }
  }

  Future<void> _acceptAndJoin() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      setState(() => _error = 'Укажите ваше имя и фамилию');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final baseUrl = ref.read(sessionProvider).value?.serverUrl ??
        ref.read(appConfigProvider).baseUrl;

    try {
      final res = await ref.read(authRepositoryProvider).acceptInvitation(
            baseUrl: baseUrl,
            token: widget.token,
            phone: _phoneController.text.trim(),
            fullName: fullName,
          );

      final user = res['user'] as String? ?? '';
      final role = res['role_name'] as String? ?? '';
      final targetRoute =
          res['landing_route'] as String? ?? Routes.routeForRole(role);

      // Sign in automatically to set session
      if (user.isNotEmpty) {
        try {
          await ref.read(sessionProvider.notifier).signIn(
                serverUrl: baseUrl,
                user: user,
                password: '', // session created server-side
              );
        } catch (_) {}
      }

      if (mounted) {
        context.go(targetRoute);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: AppBusyIndicator()),
      );
    }

    if (_error != null && _inviteInfo == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.warning, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Приглашение недействительно',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go(Routes.login),
                    child: const Text('Перейти ко входу'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final companyName = _inviteInfo?['company_name'] as String? ?? 'Цех';
    final roleTitle = _inviteInfo?['role_title_ru'] as String? ?? 'Сотрудник';
    final descRu = _inviteInfo?['desc_ru'] as String? ?? '';
    final invitedBy = _inviteInfo?['invited_by'] as String? ?? 'Руководитель';

    // Initials avatar
    final parts = companyName.split(' ');
    final initials = parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : companyName.substring(0, companyName.length.clamp(0, 2)).toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ReadableWidth(
              child: Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 48)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Приглашение в команду',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Вас пригласил $invitedBy',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Context Card
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              child: Text(
                                initials,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    companyName,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      roleTitle,
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (descRu.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      descRu,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Step 1: Phone + OTP
                    if (!_otpVerified) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Номер телефона (+7)',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        enabled: !_otpSent && !_submitting,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!_otpSent)
                        FilledButton(
                          onPressed: _submitting ? null : _sendOtp,
                          child: _submitting
                              ? const AppBusyIndicator()
                              : const Text('Получить код по SMS'),
                        ),
                      if (_otpSent) ...[
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(letterSpacing: 8, fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Код из SMS',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _submitting ? null : _verifyOtp,
                          child: _submitting
                              ? const AppBusyIndicator()
                              : const Text('Подтвердить код'),
                        ),
                      ],
                    ],

                    // Step 2: Name & Finish
                    if (_otpVerified) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ваше имя и фамилия',
                          prefixIcon: Icon(Icons.person),
                        ),
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        icon: const Icon(AppIcons.check),
                        label: _submitting
                            ? const AppBusyIndicator()
                            : const Text('Присоединиться к цеху'),
                        onPressed: _submitting ? null : _acceptAndJoin,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
