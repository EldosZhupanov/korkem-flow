import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying the company team members, invitations, position changes,
/// and access deactivation/reactivation.
///
/// Only the factory owner has permission to invite employees and manage
/// positions. Positions are selected strictly from pre-mapped ERPNext
/// role sets.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(teamMembersProvider);
    final canInviteAsync = ref.watch(canInviteProvider);
    final canInvite = canInviteAsync.value ?? false;

    final session = ref.watch(sessionProvider).value;
    final currentUser = session?.user?.trim().toLowerCase();

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
                    currentUser: currentUser,
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
    required this.currentUser,
    required this.onInviteTap,
  });

  final List<TeamMember> members;
  final bool canInvite;
  final String? currentUser;
  final VoidCallback onInviteTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final activeMembers = members.where((m) => m.enabled).toList();
    final disabledMembers = members.where((m) => !m.enabled).toList();

    // Empty state: either completely empty or only the owner is present
    final nonOwnerCount = members.where((m) => !m.isOwner).length;
    if ((members.isEmpty || (members.length <= 1 && nonOwnerCount == 0)) &&
        disabledMembers.isEmpty) {
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
          if (activeMembers.isNotEmpty) ...[
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
              itemCount: activeMembers.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final member = activeMembers[index];
                final isSelf =
                    currentUser != null &&
                    member.email.trim().toLowerCase() == currentUser;
                return _TeamMemberCard(
                  member: member,
                  isSelf: isSelf,
                  canManage: canInvite,
                  onChangePosition: () => _openChangePositionDialog(
                    context,
                    member,
                  ),
                  onDeactivate: () => _openDeactivateDialog(
                    context,
                    member,
                  ),
                  onReactivate: () => _openReactivateDialog(
                    context,
                    member,
                  ),
                );
              },
            ),
          ],
          if (disabledMembers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.teamSectionDisabled),
            const SizedBox(height: AppSpacing.xs),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: disabledMembers.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final member = disabledMembers[index];
                final isSelf =
                    currentUser != null &&
                    member.email.trim().toLowerCase() == currentUser;
                return _TeamMemberCard(
                  member: member,
                  isSelf: isSelf,
                  canManage: canInvite,
                  onChangePosition: () => _openChangePositionDialog(
                    context,
                    member,
                  ),
                  onDeactivate: () => _openDeactivateDialog(
                    context,
                    member,
                  ),
                  onReactivate: () => _openReactivateDialog(
                    context,
                    member,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openChangePositionDialog(BuildContext context, TeamMember member) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ChangePositionDialog(member: member),
      ),
    );
  }

  void _openDeactivateDialog(BuildContext context, TeamMember member) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ConfirmDeactivateDialog(member: member),
      ),
    );
  }

  void _openReactivateDialog(BuildContext context, TeamMember member) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ConfirmReactivateDialog(member: member),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    required this.isSelf,
    required this.canManage,
    required this.onChangePosition,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final TeamMember member;
  final bool isSelf;
  final bool canManage;
  final VoidCallback onChangePosition;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final statusIntent = !member.enabled
        ? StatusIntent.neutral
        // Цвет говорит про участок завода, а не про конкретный станок.
        // Тринадцать должностей и тринадцать оттенков означали бы, что цвет не
        // значит ничего: список стал бы гирляндой. Четыре области —
        // продажи, цех, склад, деньги — это то, что человек и правда различает
        // взглядом.
        : switch (member.position) {
            EmployeePosition.owner => StatusIntent.danger,
            EmployeePosition.manager ||
            EmployeePosition.measurer ||
            EmployeePosition.designer => StatusIntent.info,
            EmployeePosition.accountant => StatusIntent.success,
            EmployeePosition.warehouse ||
            EmployeePosition.installer => StatusIntent.warning,
            EmployeePosition.shopManager ||
            EmployeePosition.cutter ||
            EmployeePosition.edgeBanding ||
            EmployeePosition.cnc ||
            EmployeePosition.painter ||
            EmployeePosition.assembler ||
            EmployeePosition.shopFloor => StatusIntent.neutral,
          };

    final positionLabel = member.position.localizedName(l10n);

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: member.enabled
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: member.enabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
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
                    color: member.enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!member.enabled) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    positionLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(
            label: member.enabled ? positionLabel : l10n.teamStatusDisabled,
            intent: statusIntent,
          ),
          if (canManage && !isSelf) ...[
            const SizedBox(width: AppSpacing.xs),
            if (member.enabled)
              PopupMenuButton<String>(
                icon: const Icon(
                  AppIcons.more,
                  size: AppIconSize.small,
                ),
                tooltip: l10n.teamSectionMembers,
                onSelected: (action) {
                  if (action == 'position') {
                    onChangePosition();
                  } else if (action == 'deactivate') {
                    onDeactivate();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'position',
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.edit,
                          size: AppIconSize.small,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(l10n.teamChangePositionAction),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.noAccess,
                          size: AppIconSize.small,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.teamDeactivateAction,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              IconButton(
                tooltip: l10n.teamReactivateAction,
                icon: const Icon(
                  AppIcons.refresh,
                  size: AppIconSize.small,
                ),
                onPressed: onReactivate,
              ),
          ],
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

class _TeamLoading extends StatelessWidget {
  const _TeamLoading();

  @override
  Widget build(BuildContext context) {
    return const ListSkeleton(rows: 4);
  }
}
