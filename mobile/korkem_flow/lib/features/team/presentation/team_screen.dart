import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying the company team members and providing employee
/// invitations.
///
/// Only the factory owner has permission to invite employees and assign roles.
/// Positions are selected strictly from pre-mapped ERPNext role sets.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(teamMembersProvider);
    final canInviteAsync = ref.watch(canInviteProvider);
    final canInvite = canInviteAsync.value ?? false;

    return AppScreen(
      title: l10n.teamTitle,
      subtitle: l10n.teamSubtitle,
      actions: [
        if (canInvite)
          IconButton(
            tooltip: l10n.teamInviteButton,
            icon: const Icon(AppIcons.add),
            onPressed: () => _openInviteDialog(context),
          ),
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(teamMembersProvider),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teamMembersProvider);
          await ref.read(teamMembersProvider.future);
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
                membersAsync.when(
                  data: (members) => _TeamContent(
                    members: members,
                    canInvite: canInvite,
                    onInviteTap: () => _openInviteDialog(context),
                  ),
                  loading: () => const _TeamLoading(),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(teamMembersProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openInviteDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => const _InviteEmployeeDialog(),
      ),
    );
  }
}

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

class _TeamContent extends StatelessWidget {
  const _TeamContent({
    required this.members,
    required this.canInvite,
    required this.onInviteTap,
  });

  final List<TeamMember> members;
  final bool canInvite;
  final VoidCallback onInviteTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Empty state: either completely empty or only the owner is present
    final nonOwnerCount = members.where((m) => !m.isOwner).length;
    if (members.isEmpty || (members.length <= 1 && nonOwnerCount == 0)) {
      return Entrance(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StateIllustration(
                  icon: AppIcons.empty,
                  dense: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.teamEmptyTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.teamEmptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (canInvite) ...[
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: onInviteTap,
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.teamInviteButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(l10n.teamSectionMembers),
              if (canInvite)
                TextButton.icon(
                  onPressed: onInviteTap,
                  icon: const Icon(AppIcons.add, size: AppIconSize.small),
                  label: Text(l10n.teamInviteButton),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final member = members[index];
              return _TeamMemberCard(member: member);
            },
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final statusIntent = switch (member.position) {
      EmployeePosition.owner => StatusIntent.danger,
      EmployeePosition.manager => StatusIntent.info,
      EmployeePosition.accountant => StatusIntent.success,
      EmployeePosition.warehouse => StatusIntent.warning,
      EmployeePosition.shopFloor => StatusIntent.neutral,
    };

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(
              member.firstName.isNotEmpty
                  ? member.firstName.characters.first.toUpperCase()
                  : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(
            label: member.position.localizedName(l10n),
            intent: statusIntent,
          ),
        ],
      ),
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

  EmployeePosition _selectedPosition = EmployeePosition.shopFloor;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(teamInviteControllerProvider.notifier)
          .invite(
            email: _emailController.text.trim(),
            position: _selectedPosition,
            firstName: _firstNameController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.teamInviteSuccessDetail(
                result.user,
                _selectedPosition.localizedName(l10n),
              ),
            ),
          ),
        );
      }
    } on TeamForbiddenException {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = l10n.teamForbiddenMessage;
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
        child: Padding(
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
                DropdownButtonFormField<EmployeePosition>(
                  initialValue: _selectedPosition,
                  decoration: InputDecoration(
                    labelText: l10n.teamPositionLabel,
                    prefixIcon: const Icon(AppIcons.task),
                  ),
                  items: [
                    for (final pos in EmployeePosition.selectable)
                      DropdownMenuItem(
                        value: pos,
                        child: Text(pos.localizedName(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPosition = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _selectedPosition.localizedDescription(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.actionCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
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

class _TeamLoading extends StatelessWidget {
  const _TeamLoading();

  @override
  Widget build(BuildContext context) {
    return const ListSkeleton(rows: 4);
  }
}
