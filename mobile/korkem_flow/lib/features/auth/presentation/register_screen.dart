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
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Redesigned Registration screen supporting TWO ONBOARDING PATHS:
/// 1. CREATE COMPANY (Owner wizard: Phone+OTP -> Profile -> Company+Logo -> Success)
/// 2. JOIN COMPANY BY INVITE (Link / code input -> JoinInviteScreen)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;

  // Path 0 = Create Company, 1 = Join Company
  int _selectedPath = 0;

  // Owner Steps: 1 = Phone & OTP, 2 = Profile, 3 = Company, 4 = Success
  int _ownerStep = 1;

  final _phone = TextEditingController(text: '+7 ');
  final _otp = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _company = TextEditingController();
  final _inviteCode = TextEditingController();

  bool _otpSent = false;
  bool _otpVerified = false;
  String _sessionId = '';

  bool _busy = false;
  String? _failure;
  String? _logoBase64;
  String _createdCompany = '';

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
    _phone.dispose();
    _otp.dispose();
    _ownerName.dispose();
    _email.dispose();
    _password.dispose();
    _company.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty || phone == '+7') {
      setState(() => _failure = 'Укажите номер телефона (+7)');
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    final serverUrl = _server.text.trim().isNotEmpty
        ? _server.text.trim()
        : ref.read(appConfigProvider).baseUrl;

    try {
      final res = await ref.read(authRepositoryProvider).requestOtp(
            baseUrl: serverUrl,
            phone: phone,
          );
      setState(() {
        _otpSent = true;
        _sessionId = res['session_id'] as String? ?? '';
        final devCode = res['dev_code'] as String?;
        if (devCode != null && devCode.isNotEmpty) {
          _otp.text = devCode;
        }
      });
    } on Object catch (e) {
      setState(() => _failure = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.isEmpty) {
      setState(() => _failure = 'Введите код из SMS');
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    final serverUrl = _server.text.trim().isNotEmpty
        ? _server.text.trim()
        : ref.read(appConfigProvider).baseUrl;

    try {
      final res = await ref.read(authRepositoryProvider).verifyOtp(
            baseUrl: serverUrl,
            phone: _phone.text.trim(),
            code: code,
            sessionId: _sessionId,
          );

      if (res['verified'] == true) {
        setState(() {
          _otpVerified = true;
          _ownerStep = 2; // Advance to Profile
        });
      } else {
        setState(() => _failure = 'Неверный код подтверждения');
      }
    } on Object catch (e) {
      setState(() => _failure = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _submitOwnerRegistration() async {
    final company = _company.text.trim();
    if (company.isEmpty) {
      setState(() => _failure = 'Укажите название цеха');
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    final serverUrl = _server.text.trim().isNotEmpty
        ? _server.text.trim()
        : ref.read(appConfigProvider).baseUrl;

    final pwd = _password.text.trim().isNotEmpty
        ? _password.text.trim()
        : 'KorkemPilot2026!';

    try {
      final res = await ref.read(authRepositoryProvider).register(
            baseUrl: serverUrl,
            companyName: company,
            ownerName: _ownerName.text.trim(),
            email: _email.text.trim(),
            password: pwd,
            phone: _phone.text.trim(),
            logoBase64: _logoBase64,
          );

      _createdCompany = company;

      // Auto sign in
      final effectiveEmail = res['email'] as String? ?? _email.text.trim();
      if (effectiveEmail.isNotEmpty) {
        try {
          await ref.read(sessionProvider.notifier).signIn(
                serverUrl: serverUrl,
                user: effectiveEmail,
                password: pwd,
              );
        } catch (_) {}
      }

      setState(() {
        _ownerStep = 4; // Advance to Success step
      });
    } on FrappeException catch (error) {
      setState(() => _failure = error.message);
    } on Object catch (error) {
      setState(() => _failure = '$error');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _handleJoinByInvite() {
    final raw = _inviteCode.text.trim();
    if (raw.isEmpty) return;
    String targetToken = raw;
    if (raw.contains('/join/')) {
      targetToken = raw.split('/join/')[1].split('?')[0].split('#')[0];
    }
    context.push('/join/$targetToken');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Initials avatar
    final compText = _company.text.trim();
    final parts = compText.split(' ');
    final initials = parts.length > 1 && parts[1].isNotEmpty
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : compText.isNotEmpty
            ? compText.substring(0, compText.length.clamp(0, 2)).toUpperCase()
            : 'KM';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ReadableWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: AppLogo(layout: LogoLayout.lockup, size: 180),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Вход и регистрация в KORKEM Flow',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Mode Selector (Two onboarding paths)
                      if (_ownerStep != 4) ...[
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Создать компанию'),
                              icon: Icon(Icons.business),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('По приглашению'),
                              icon: Icon(Icons.person),
                            ),
                          ],
                          selected: {_selectedPath},
                          onSelectionChanged: (set) {
                            setState(() {
                              _selectedPath = set.first;
                              _failure = null;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      if (_failure != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _failure!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // PATH 1: Join Company
                      if (_selectedPath == 1 && _ownerStep != 4) ...[
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Присоединиться к цеху',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Вставьте ссылку из WhatsApp / Telegram или короткий код приглашения:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _inviteCode,
                                  decoration: const InputDecoration(
                                    hintText: 'https://korkem.asia/join/... или код',
                                    prefixIcon: Icon(Icons.qr_code),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton(
                                  onPressed: _handleJoinByInvite,
                                  child: const Text('Перейти к приглашению'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // PATH 0: Create Company Wizard
                      if (_selectedPath == 0) ...[
                        // STEP 1: Phone + OTP
                        if (_ownerStep == 1) ...[
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Шаг 1: Номер телефона',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('1 / 3', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Быстрое подтверждение без лишних паролей',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Телефон (+7)',
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    enabled: !_otpSent && !_busy,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  if (!_otpSent)
                                    FilledButton(
                                      onPressed: _busy ? null : _sendOtp,
                                      child: _busy
                                          ? const AppBusyIndicator()
                                          : const Text('Получить код по SMS'),
                                    ),
                                  if (_otpSent) ...[
                                    TextFormField(
                                      controller: _otp,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        letterSpacing: 6,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Код из SMS',
                                        counterText: '',
                                        suffixIcon: IconButton(
                                          icon: const Icon(AppIcons.refresh),
                                          onPressed: _sendOtp,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    FilledButton(
                                      onPressed: _busy ? null : _verifyOtp,
                                      child: _busy
                                          ? const AppBusyIndicator()
                                          : const Text('Подтвердить код'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],

                        // STEP 2: Owner Profile
                        if (_ownerStep == 2) ...[
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Шаг 2: Профиль владельца',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('2 / 3', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Как к вам обращаться в отчетах и документах',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _ownerName,
                                    decoration: const InputDecoration(
                                      labelText: 'Имя и фамилия *',
                                      hintText: 'Аслан Ахметов',
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Email (необязательно)',
                                      prefixIcon: Icon(AppIcons.email),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Пароль (не менее 6 знаков)',
                                      prefixIcon: Icon(Icons.lock),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => setState(() => _ownerStep = 1),
                                        child: const Text('Назад'),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () {
                                            if (_ownerName.text.trim().isEmpty) {
                                              setState(() => _failure = 'Укажите ваше имя');
                                              return;
                                            }
                                            setState(() {
                                              _failure = null;
                                              _ownerStep = 3;
                                            });
                                          },
                                          child: const Text('Далее'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // STEP 3: Company & Logo
                        if (_ownerStep == 3) ...[
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Шаг 3: Название цеха',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('3 / 3', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Название фабрики или мастерской',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _company,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Название компании / цеха *',
                                      hintText: 'Престиж Мебель',
                                      prefixIcon: Icon(Icons.business),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  // Logo fallback
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          child: Text(
                                            initials,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Логотип цеха',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text(
                                                'По умолчанию инициалы «$initials». Логотип можно загрузить позже в профиле.',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => setState(() => _ownerStep = 2),
                                        child: const Text('Назад'),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _busy ? null : _submitOwnerRegistration,
                                          child: _busy
                                              ? const AppBusyIndicator()
                                              : const Text('Создать компанию'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // STEP 4: Success Screen
                        if (_ownerStep == 4) ...[
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Icon(AppIcons.check, size: 48, color: theme.colorScheme.primary),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Компания «$_createdCompany» создана!',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Рабочее пространство настроено. Начните работу прямо сейчас:',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),

                                  FilledButton.icon(
                                    icon: const Icon(Icons.person),
                                    label: const Text('Пригласить сотрудников (WhatsApp)'),
                                    onPressed: () => context.go(Routes.team),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  OutlinedButton.icon(
                                    icon: const Icon(AppIcons.add),
                                    label: const Text('Создать первый заказ'),
                                    onPressed: () => context.go(Routes.orders),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextButton.icon(
                                    icon: const Icon(AppIcons.dashboard),
                                    label: const Text('Открыть Dashboard'),
                                    onPressed: () => context.go(Routes.dashboard),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.authAlreadyHaveAccount,
                            style: theme.textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () => context.go(Routes.login),
                            child: Text(l10n.authSignIn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
