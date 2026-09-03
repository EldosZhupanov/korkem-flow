import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/company_details/application/company_details_controller.dart';
import 'package:korkem_flow/features/company_details/domain/company_details.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Company legal, address, and banking credentials.
///
/// Details entered here populate contracts, commercial proposals, and
/// waybills without requiring access to ERPNext Desk.
class CompanyDetailsScreen extends ConsumerWidget {
  const CompanyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailsAsync = ref.watch(companyDetailsProvider);

    return AppScreen(
      title: l10n.companyDetailsTitle,
      subtitle: l10n.companyDetailsSubtitle,
      actions: [
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(companyDetailsProvider),
        ),
      ],
      body: detailsAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(companyDetailsProvider),
        ),
        data: (details) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyDetailsProvider);
            await ref.read(companyDetailsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: ReadableWidth(
              child: _CompanyDetailsForm(initialDetails: details),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyDetailsForm extends ConsumerStatefulWidget {
  const _CompanyDetailsForm({required this.initialDetails});

  final CompanyDetails initialDetails;

  @override
  ConsumerState<_CompanyDetailsForm> createState() =>
      _CompanyDetailsFormState();
}

class _CompanyDetailsFormState extends ConsumerState<_CompanyDetailsForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _binController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _bikController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDetails;
    _nameController = TextEditingController(text: d.name);
    _binController = TextEditingController(text: d.bin);
    _cityController = TextEditingController(text: d.city);
    _addressController = TextEditingController(text: d.address);
    _phoneController = TextEditingController(text: d.phone);
    _emailController = TextEditingController(text: d.email);
    _websiteController = TextEditingController(text: d.website);
    _bankNameController = TextEditingController(text: d.bankName);
    _bankAccountController = TextEditingController(text: d.bankAccount);
    _bikController = TextEditingController(text: d.bik);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bikController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final updated = CompanyDetails(
      company: widget.initialDetails.company,
      name: widget.initialDetails.name,
      bin: _binController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      bankName: _bankNameController.text.trim(),
      bankAccount: _bankAccountController.text.replaceAll(' ', '').trim(),
      bik: _bikController.text.trim(),
    );

    try {
      await ref.read(companyDetailsControllerProvider.notifier).save(updated);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.companyDetailsSaveSuccess)),
        );
      }
    } on PermissionFailure catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.message.isNotEmpty
              ? e.message
              : l10n.teamForbiddenMessage;
        });
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DocNoteBanner(text: l10n.companyDetailsDocNote),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.danger,
                    color: theme.colorScheme.onErrorContainer,
                    size: AppIconSize.small,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SectionLabel(l10n.companyDetailsSectionGeneral),
          AppCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsNameLabel,
                    hintText: l10n.companyDetailsNameHint,
                    helperText: l10n.companyDetailsReadOnlyNameNotice,
                    prefixIcon: const Icon(AppIcons.lead),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _binController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsBinLabel,
                    hintText: l10n.companyDetailsBinHint,
                    prefixIcon: const Icon(AppIcons.quote),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (text.length != 12 ||
                        !RegExp(r'^\d{12}$').hasMatch(text)) {
                      return l10n.companyDetailsBinError;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.companyDetailsSectionContacts),
          AppCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsCityLabel,
                    hintText: l10n.companyDetailsCityHint,
                    prefixIcon: const Icon(AppIcons.customer),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsAddressLabel,
                    hintText: l10n.companyDetailsAddressHint,
                    prefixIcon: const Icon(AppIcons.warehouse),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsPhoneLabel,
                    hintText: l10n.companyDetailsPhoneHint,
                    prefixIcon: const Icon(AppIcons.call),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsEmailLabel,
                    hintText: l10n.companyDetailsEmailHint,
                    prefixIcon: const Icon(AppIcons.email),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (!text.contains('@') || !text.contains('.')) {
                      return l10n.companyDetailsEmailError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsWebsiteLabel,
                    hintText: l10n.companyDetailsWebsiteHint,
                    prefixIcon: const Icon(AppIcons.settings),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.companyDetailsSectionBank),
          AppCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsBankNameLabel,
                    hintText: l10n.companyDetailsBankNameHint,
                    prefixIcon: const Icon(AppIcons.deal),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bankAccountController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsIbanLabel,
                    hintText: l10n.companyDetailsIbanHint,
                    helperText: l10n.companyDetailsIbanHelper,
                    prefixIcon: const Icon(AppIcons.quote),
                  ),
                  validator: (value) {
                    final text = (value ?? '').replaceAll(' ', '').trim();
                    if (text.isEmpty) return null;
                    if (text.length != 20 ||
                        !RegExp(r'^KZ[0-9A-Za-z]{18}$').hasMatch(text)) {
                      return l10n.companyDetailsIbanError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bikController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.companyDetailsBikLabel,
                    hintText: l10n.companyDetailsBikHint,
                    prefixIcon: const Icon(AppIcons.item),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (text.length < 8 ||
                        text.length > 11 ||
                        !RegExp(r'^[A-Za-z0-9]+$').hasMatch(text)) {
                      return l10n.companyDetailsBikError;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => unawaited(_submit()),
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: AppIconSize.small,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.focus,
                    ),
                  )
                : const Icon(AppIcons.check),
            label: Text(l10n.companyDetailsSaveButton),
          ),
        ],
      ),
    );
  }
}

class _DocNoteBanner extends StatelessWidget {
  const _DocNoteBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.info,
            size: AppIconSize.small,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
