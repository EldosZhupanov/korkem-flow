import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/features/team/presentation/trades_dialog.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Команда»: everyone at the company in one list — by department and post,
/// with or without a login — and, from a person, his login: invitation,
/// access, closing and reopening.
///
/// Only the factory owner has permission to invite employees and manage
/// positions. Positions are selected strictly from pre-mapped ERPNext
/// role sets.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canInviteAsync = ref.watch(canInviteProvider);
    final canInvite = canInviteAsync.value ?? false;
    // The logins' access and trades, read when a person's login is opened.
    ref.watch(teamMembersProvider);

    return AppScreen(
      title: l10n.teamTitle,
      subtitle: l10n.teamSubtitle,
      actions: [
        if (canInvite)
          IconButton(
            tooltip: l10n.teamInviteButton,
            icon: const Icon(AppIcons.add),
            onPressed: () => unawaited(showTeamInviteDialog(context)),
          ),
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref
            ..invalidate(teamMembersProvider)
            ..invalidate(teamPeopleProvider),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(teamMembersProvider)
            ..invalidate(teamPeopleProvider);
          await ref.read(teamPeopleProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canInvite && canInviteAsync.hasValue) ...[
                  _ForbiddenNoticeBanner(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // One list (owner, 17.11.2026: «команда и люди одно и то
                // же»): the departments, their posts and the people on them;
                // a login is a mark on a person, opened from his card.
                TeamDepartmentsView(canManageLogins: canInvite),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What can be done to a person's login from «Команда».
enum TeamLoginAction { position, trades, close, open }

/// Invite someone into the program; accepting joins the person with the
/// same phone, or makes one (`services/team.join`).
Future<void> showTeamInviteDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _InviteEmployeeDialog(),
);

/// A login's access, trades, closing or opening — the dialogs the logins'
/// own list had, now reached from the person.
Future<void> showTeamLoginAction(
  BuildContext context,
  TeamMember member,
  TeamLoginAction action,
) => switch (action) {
  TeamLoginAction.trades => showTradesDialog(context, member),
  TeamLoginAction.position => showDialog<void>(
    context: context,
    builder: (context) => _ChangePositionDialog(member: member),
  ),
  TeamLoginAction.close => showDialog<void>(
    context: context,
    builder: (context) => _ConfirmDeactivateDialog(member: member),
  ),
  TeamLoginAction.open => showDialog<void>(
    context: context,
    builder: (context) => _ConfirmReactivateDialog(member: member),
  ),
};


class _ForbiddenNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.noAccess,
            color: theme.colorScheme.onSurfaceVariant,
            size: AppIconSize.normal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.teamForbiddenTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.teamForbiddenMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDeactivateDialog extends ConsumerStatefulWidget {
  const _ConfirmDeactivateDialog({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_ConfirmDeactivateDialog> createState() =>
      _ConfirmDeactivateDialogState();
}

class _ConfirmDeactivateDialogState
    extends ConsumerState<_ConfirmDeactivateDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(teamRepositoryProvider)
          .deactivate(email: widget.member.email);
      ref.invalidate(teamMembersProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showDone(
          l10n.teamDeactivateSuccess(result.sessionsClosed),
        );
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final displayName = widget.member.fullName.isNotEmpty
        ? widget.member.fullName
        : widget.member.firstName;

    return AlertDialog(
      title: Text(l10n.teamDeactivateDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.teamDeactivateConfirmMessage(displayName),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppIconSize.small,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.teamDeactivateConfirmButton),
        ),
      ],
    );
  }
}

class _ChangePositionDialog extends ConsumerStatefulWidget {
  const _ChangePositionDialog({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_ChangePositionDialog> createState() =>
      _ChangePositionDialogState();
}

class _ChangePositionDialogState extends ConsumerState<_ChangePositionDialog> {
  String? _selectedPosition;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.member.position.id;
  }

  Future<void> _submit(List<PositionOption> positions) async {
    final pos =
        _selectedPosition ??
        (positions.isNotEmpty ? positions.first.position : null);
    if (pos == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(teamRepositoryProvider)
          .changePosition(
            email: widget.member.email,
            position: pos,
          );
      ref.invalidate(teamMembersProvider);

      if (mounted) {
        Navigator.of(context).pop();
        final selectedOption = positions
            .where((p) => p.position == result.position)
            .firstOrNull;
        final posName =
            selectedOption?.localizedName(l10n) ??
            EmployeePosition.fromId(result.position).localizedName(l10n);
        final displayName = widget.member.fullName.isNotEmpty
            ? widget.member.fullName
            : widget.member.firstName;
        ScaffoldMessenger.of(context).showDone(
          l10n.teamChangePositionSuccess(displayName, posName),
        );
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final positionsAsync = ref.watch(teamPositionsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.teamChangePositionTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.member.fullName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.member.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              positionsAsync.when(
                data: (positions) {
                  final effectivePosition =
                      _selectedPosition != null &&
                          positions.any((p) => p.position == _selectedPosition)
                      ? _selectedPosition
                      : (positions.isNotEmpty
                            ? positions.first.position
                            : null);

                  return DropdownButtonFormField<String>(
                    initialValue: effectivePosition,
                    decoration: InputDecoration(
                      labelText: l10n.teamPositionLabel,
                      prefixIcon: const Icon(AppIcons.task),
                    ),
                    items: [
                      for (final pos in positions)
                        DropdownMenuItem(
                          value: pos.position,
                          child: Text(pos.localizedName(l10n)),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedPosition = val);
                            }
                          },
                  );
                },
                loading: () => InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.teamPositionLabel,
                  ),
                  child: Text(
                    l10n.teamPositionsLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                error: (_, _) => InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.teamPositionLabel,
                    errorText: l10n.teamPositionsLoadError,
                  ),
                  child: const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            final positions = positionsAsync.value ?? const [];
                            unawaited(_submit(positions));
                          },
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: AppIconSize.small,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.teamSavePosition),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmReactivateDialog extends ConsumerStatefulWidget {
  const _ConfirmReactivateDialog({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_ConfirmReactivateDialog> createState() =>
      _ConfirmReactivateDialogState();
}

class _ConfirmReactivateDialogState
    extends ConsumerState<_ConfirmReactivateDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(teamRepositoryProvider)
          .reactivate(email: widget.member.email);
      ref.invalidate(teamMembersProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showDone(l10n.teamReactivateSuccess);
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final displayName = widget.member.fullName.isNotEmpty
        ? widget.member.fullName
        : widget.member.firstName;

    return AlertDialog(
      title: Text(l10n.teamReactivateDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.teamReactivateConfirmMessage(displayName),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppIconSize.small,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.teamReactivateConfirmButton),
        ),
      ],
    );
  }
}

class _InviteEmployeeDialog extends ConsumerStatefulWidget {
  const _InviteEmployeeDialog();

  @override
  ConsumerState<_InviteEmployeeDialog> createState() =>
      _InviteEmployeeDialogState();
}

class _InviteEmployeeDialogState extends ConsumerState<_InviteEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();

  String? _selectedPosition;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<PositionOption> positions) async {
    if (!_formKey.currentState!.validate()) return;
    final pos =
        _selectedPosition ??
        (positions.isNotEmpty ? positions.first.position : null);
    if (pos == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(teamInviteControllerProvider.notifier)
          .invite(
            email: _emailController.text.trim(),
            position: pos,
            firstName: _firstNameController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => _InviteSuccessDialog(result: result),
          ),
        );
      }
    } on TeamForbiddenException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on FrappeException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final positionsAsync = ref.watch(teamPositionsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.lead,
                      color: theme.colorScheme.primary,
                      size: AppIconSize.normal,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.teamInviteTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.teamInviteSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l10n.teamEmailLabel,
                    hintText: l10n.teamEmailHint,
                    prefixIcon: const Icon(AppIcons.email),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty || !text.contains('@')) {
                      return l10n.teamEmailError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.teamFirstNameLabel,
                    hintText: l10n.teamFirstNameHint,
                    prefixIcon: const Icon(AppIcons.profile),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                positionsAsync.when(
                  data: (positions) {
                    final effectivePosition =
                        _selectedPosition != null &&
                            positions.any(
                              (p) => p.position == _selectedPosition,
                            )
                        ? _selectedPosition
                        : (positions.isNotEmpty
                              ? positions.first.position
                              : null);

                    final selectedOption = positions
                        .where((p) => p.position == effectivePosition)
                        .firstOrNull;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: effectivePosition,
                          decoration: InputDecoration(
                            labelText: l10n.teamPositionLabel,
                            prefixIcon: const Icon(AppIcons.task),
                          ),
                          items: [
                            for (final pos in positions)
                              DropdownMenuItem(
                                value: pos.position,
                                child: Text(pos.localizedName(l10n)),
                              ),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _selectedPosition = value);
                                  }
                                },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.teamPositionLabel;
                            }
                            return null;
                          },
                        ),
                        if (selectedOption != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            selectedOption.localizedDescription(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.teamPositionLabel,
                      prefixIcon: const Icon(AppIcons.task),
                    ),
                    child: Text(
                      l10n.teamPositionsLoading,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  error: (e, _) => InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.teamPositionLabel,
                      prefixIcon: const Icon(AppIcons.danger),
                    ),
                    child: Text(
                      l10n.teamPositionsLoadError,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.actionCancel),
                    ),
                    FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              final positions =
                                  positionsAsync.value ?? const [];
                              unawaited(_submit(positions));
                            },
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: AppIconSize.small,
                              child: CircularProgressIndicator(
                                strokeWidth: AppStroke.focus,
                              ),
                            )
                          : Text(l10n.teamSendInvite),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteSuccessDialog extends StatelessWidget {
  const _InviteSuccessDialog({required this.result});

  final TeamInviteResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final positionName = result.position.localizedName(l10n);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.success,
                    color: theme.colorScheme.primary,
                    size: AppIconSize.normal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.teamInviteSuccessTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.teamInviteSuccessDetail(result.user, positionName),
                style: theme.textTheme.bodyMedium,
              ),
              if (result.nextStep != null &&
                  result.nextStep!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AppIcons.info,
                            size: AppIconSize.small,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.teamNextStepTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        result.nextStep!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!result.passwordSet) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      AppIcons.warning,
                      size: AppIconSize.dense,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l10n.teamPasswordNotSet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
