import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/enquiry_flow/application/enquiry_flow_controller.dart';
import 'package:korkem_flow/features/enquiry_flow/application/image_picker_service.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen guiding a customer request through the full 4-step pipeline:
/// Enquiry → Measurement → Proposal → Order.
class EnquiryFlowScreen extends ConsumerStatefulWidget {
  const EnquiryFlowScreen({this.initialCaptureId, super.key});

  final String? initialCaptureId;

  @override
  ConsumerState<EnquiryFlowScreen> createState() => _EnquiryFlowScreenState();
}

class _EnquiryFlowScreenState extends ConsumerState<EnquiryFlowScreen> {
  String? _selectedCaptureId;

  @override
  void initState() {
    super.initState();
    _selectedCaptureId = widget.initialCaptureId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capturesAsync = ref.watch(recentCapturesProvider);

    return AppScreen(
      title: l10n.enquiryFlowTitle,
      subtitle: l10n.enquiryFlowSubtitle,
      body: capturesAsync.when(
        data: (captures) {
          if (captures.isEmpty) {
            return _EmptyCapturesView();
          }

          final activeCaptureId = _selectedCaptureId ?? captures.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (captures.length > 1) ...[
                    _CaptureSelectorHeader(
                      captures: captures,
                      selectedId: activeCaptureId,
                      onChanged: (id) =>
                          setState(() => _selectedCaptureId = id),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _PipelineBody(captureId: activeCaptureId),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recentCapturesProvider),
        ),
      ),
    );
  }
}

class _EmptyCapturesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StateIllustration(icon: AppIcons.empty, dense: true),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.enquiryFlowEmptyCaptures,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.enquiryFlowEmptyCapturesDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSelectorHeader extends StatelessWidget {
  const _CaptureSelectorHeader({
    required this.captures,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CaptureSummary> captures;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(
        labelText: l10n.enquiryFlowSelectCapture,
        prefixIcon: const Icon(AppIcons.lead),
      ),
      items: [
        for (final c in captures)
          DropdownMenuItem(
            value: c.id,
            child: Text(
              '${c.customerHint ?? c.spokenText} (${c.status})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }
}

class _PipelineBody extends ConsumerWidget {
  const _PipelineBody({required this.captureId});

  final String captureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineAsync = ref.watch(enquiryPipelineProvider(captureId));

    return pipelineAsync.when(
      data: (data) => _PipelineFlow(data: data),
      loading: () => const ListSkeleton(rows: 4),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(enquiryPipelineProvider(captureId)),
      ),
    );
  }
}

class _PipelineFlow extends StatelessWidget {
  const _PipelineFlow({required this.data});

  final EnquiryFlowPipelineData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PipelineStepperHeader(activeStep: data.currentStep),
        const SizedBox(height: AppSpacing.xl),
        _Step1EnquirySection(data: data),
        const SizedBox(height: AppSpacing.lg),
        _Step2MeasurementSection(data: data),
        const SizedBox(height: AppSpacing.lg),
        _Step3ProposalSection(data: data),
        const SizedBox(height: AppSpacing.lg),
        _Step4OrderSection(data: data),
      ],
    );
  }
}

class _PipelineStepperHeader extends StatelessWidget {
  const _PipelineStepperHeader({required this.activeStep});

  final EnquiryFlowStep activeStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (EnquiryFlowStep.enquiry, l10n.enquiryFlowStep1),
      (EnquiryFlowStep.measurement, l10n.enquiryFlowStep2),
      (EnquiryFlowStep.proposal, l10n.enquiryFlowStep3),
      (EnquiryFlowStep.order, l10n.enquiryFlowStep4),
    ];

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepBadge(
              step: steps[i].$1,
              label: steps[i].$2,
              isActive: activeStep == steps[i].$1,
              isCompleted: activeStep.number > steps[i].$1.number,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: AppStroke.hairline,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final EnquiryFlowStep step;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color circleColor;
    final Color textColor;
    final Widget circleContent;

    if (isCompleted) {
      circleColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      circleContent = Icon(
        AppIcons.check,
        size: AppIconSize.dense,
        color: textColor,
      );
    } else if (isActive) {
      circleColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      circleContent = Text(
        '${step.number}',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    } else {
      circleColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
      circleContent = Text(
        '${step.number}',
        style: theme.textTheme.labelMedium?.copyWith(color: textColor),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: AppSpacing.sm + AppSpacing.xxs,
          backgroundColor: circleColor,
          child: circleContent,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── STEP 1: ENQUIRY ──────────────────────────────────────────────────────────

class _Step1EnquirySection extends ConsumerStatefulWidget {
  const _Step1EnquirySection({required this.data});

  final EnquiryFlowPipelineData data;

  @override
  ConsumerState<_Step1EnquirySection> createState() =>
      _Step1EnquirySectionState();
}

class _Step1EnquirySectionState extends ConsumerState<_Step1EnquirySection> {
  final _customerController = TextEditingController();
  String? _assignMeasurer;
  DateTime? _measureDate;
  List<CustomerCandidate>? _ambiguousCandidates;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customerController.text = widget.data.capture.customerHint ?? '';
  }

  Future<void> _convert({
    String? chosenCustomer,
    String? newCustomerName,
  }) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dateStr = _measureDate != null
          ? '${_measureDate!.year}-'
                '${_measureDate!.month.toString().padLeft(2, '0')}-'
                '${_measureDate!.day.toString().padLeft(2, '0')}'
          : null;

      await ref
          .read(enquiryFlowActionsProvider)
          .convert(
            captureId: widget.data.capture.id,
            customer: chosenCustomer,
            customerName: newCustomerName ?? _customerController.text.trim(),
            assignMeasurer: _assignMeasurer,
            measureOn: dateStr,
          );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _ambiguousCandidates = null;
        });
      }
    } on AmbiguousCustomerException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _ambiguousCandidates = e.candidates;
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
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDone = widget.data.isEnquiryCreated;
    final teamAsync = ref.watch(teamMembersProvider);

    return Entrance(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel(
                  '1. ${l10n.enquiryFlowStep1}: ${l10n.enquiryFlowSpokenText}',
                ),
                StatusChip(
                  label: isDone ? l10n.qOpen : widget.data.capture.status,
                  intent: isDone ? StatusIntent.success : StatusIntent.info,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '«${widget.data.capture.spokenText}»',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isDone) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.check, size: AppIconSize.small),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${l10n.enquiryFlowStep1}: '
                        '${widget.data.enquiryId} · ${widget.data.customer}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_ambiguousCandidates != null) ...[
                _AmbiguousCandidatesCard(
                  candidates: _ambiguousCandidates!,
                  onSelectCandidate: (candidate) =>
                      _convert(chosenCustomer: candidate.name),
                  onCreateNew: () => _convert(
                    newCustomerName: _customerController.text.trim(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _customerController,
                decoration: InputDecoration(
                  labelText: l10n.enquiryFlowCustomerName,
                  prefixIcon: const Icon(AppIcons.lead),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              teamAsync.when(
                data: (members) => DropdownButtonFormField<String>(
                  initialValue: _assignMeasurer,
                  decoration: InputDecoration(
                    labelText: l10n.enquiryFlowAssignMeasurer,
                    prefixIcon: const Icon(AppIcons.profile),
                  ),
                  items: [
                    for (final m in members)
                      DropdownMenuItem(
                        value: m.email,
                        child: Text(
                          '${m.fullName} '
                          '(${m.position.localizedName(l10n)})',
                        ),
                      ),
                  ],
                  onChanged: (val) => setState(() => _assignMeasurer = val),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _convert,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: AppIconSize.small,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.focus,
                        ),
                      )
                    : const Icon(AppIcons.forward),
                label: Text(l10n.enquiryFlowConvertAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmbiguousCandidatesCard extends StatelessWidget {
  const _AmbiguousCandidatesCard({
    required this.candidates,
    required this.onSelectCandidate,
    required this.onCreateNew,
  });

  final List<CustomerCandidate> candidates;
  final ValueChanged<CustomerCandidate> onSelectCandidate;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(
          alpha: AppTint.surface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: AppTint.ornamentOnDark,
          ),
        ),
      ),
      child: Column(
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
                  l10n.enquiryFlowAmbiguousTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.enquiryFlowAmbiguousSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final candidate in candidates) ...[
            Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                leading: const Icon(AppIcons.profile, size: AppIconSize.normal),
                title: Text(candidate.customerName),
                subtitle: candidate.mobileNo != null
                    ? Text(candidate.mobileNo!)
                    : null,
                trailing: const Icon(AppIcons.forward, size: AppIconSize.small),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                onTap: () => onSelectCandidate(candidate),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onCreateNew,
            child: Text(l10n.enquiryFlowCreateNewCustomer),
          ),
        ],
      ),
    );
  }
}

// ── STEP 2: MEASUREMENT ──────────────────────────────────────────────────────

class _Step2MeasurementSection extends ConsumerStatefulWidget {
  const _Step2MeasurementSection({required this.data});

  final EnquiryFlowPipelineData data;

  @override
  ConsumerState<_Step2MeasurementSection> createState() =>
      _Step2MeasurementSectionState();
}

class _Step2MeasurementSectionState
    extends ConsumerState<_Step2MeasurementSection> {
  final _dimensionsController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  String? _errorMessage;
  String? _permissionErrorMessage;
  bool _isSubmitting = false;

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final photo = await picker.pickImageFromCamera();
      if (photo != null) {
        setState(() {
          _selectedPhotos.add(photo);
          _permissionErrorMessage = null;
        });
      }
    } on ImagePickerPermissionException {
      setState(() {
        _permissionErrorMessage = l10n.enquiryFlowPermissionDenied;
      });
    } on Object catch (e) {
      setState(() {
        _permissionErrorMessage = '$e';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final photos = await picker.pickMultiImage();
      if (photos.isNotEmpty) {
        setState(() {
          _selectedPhotos.addAll(photos);
          _permissionErrorMessage = null;
        });
      }
    } on ImagePickerPermissionException {
      setState(() {
        _permissionErrorMessage = l10n.enquiryFlowPermissionDenied;
      });
    } on Object catch (e) {
      setState(() {
        _permissionErrorMessage = '$e';
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final dim = _dimensionsController.text.trim();
    final notes = _notesController.text.trim();

    if (dim.isEmpty && notes.isEmpty && _selectedPhotos.isEmpty) {
      setState(() {
        _errorMessage = l10n.enquiryFlowDimensions;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _permissionErrorMessage = null;
    });

    try {
      await ref
          .read(enquiryFlowActionsProvider)
          .recordMeasurement(
            captureId: widget.data.capture.id,
            enquiry: widget.data.enquiryId!,
            dimensions: dim.isNotEmpty ? dim : null,
            notes: notes.isNotEmpty ? notes : null,
            addressLine: _addressController.text.trim(),
            city: _cityController.text.trim(),
            photos: List<XFile>.unmodifiable(_selectedPhotos),
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
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
  void dispose() {
    _dimensionsController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEnquiryReady = widget.data.isEnquiryCreated;
    final isDone = widget.data.isMeasured || widget.data.isQuotationDrafted;

    if (!isEnquiryReady) {
      return AppCard(
        child: Opacity(
          opacity: AppTint.shimmerRest,
          child: Row(
            children: [
              const Icon(AppIcons.task),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '2. ${l10n.enquiryFlowStep2}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Entrance(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('2. ${l10n.enquiryFlowStep2}'),
                StatusChip(
                  label: isDone ? l10n.qReplied : l10n.qOpen,
                  intent: isDone ? StatusIntent.success : StatusIntent.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isDone) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.enquiryFlowStep2}: '
                      '${widget.data.measurement?.dimensions ?? 'Выполнен'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.data.measurement?.photos.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.camera,
                            size: AppIconSize.dense,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.enquiryFlowPhotosCount(
                              widget.data.measurement!.photos.length,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _dimensionsController,
                decoration: InputDecoration(
                  labelText: l10n.enquiryFlowDimensions,
                  hintText: l10n.enquiryFlowDimensionsHint,
                  prefixIcon: const Icon(AppIcons.item),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.enquiryFlowNotes,
                  hintText: l10n.enquiryFlowNotesHint,
                  prefixIcon: const Icon(AppIcons.task),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: l10n.enquiryFlowAddress,
                        hintText: l10n.enquiryFlowAddressHint,
                        prefixIcon: const Icon(AppIcons.warehouse),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: l10n.enquiryFlowCity,
                        hintText: l10n.enquiryFlowCityHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Photos and references ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.enquiryFlowAttachPhotos,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedPhotos.isNotEmpty)
                    StatusChip(
                      label: '${_selectedPhotos.length}',
                      intent: StatusIntent.info,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_permissionErrorMessage != null) ...[
                _ErrorBanner(message: _permissionErrorMessage!),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isSubmitting ? null : _takePhoto,
                      icon: const Icon(AppIcons.camera),
                      label: Text(l10n.enquiryFlowTakePhoto),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _pickFromGallery,
                      icon: const Icon(AppIcons.gallery),
                      label: Text(l10n.enquiryFlowPickGallery),
                    ),
                  ),
                ],
              ),
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: AppPlaceholder.rowHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedPhotos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _PhotoThumbnail(
                        photo: _selectedPhotos[index],
                        onRemove: () => _removePhoto(index),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: AppIconSize.small,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.focus,
                        ),
                      )
                    : const Icon(AppIcons.check),
                label: Text(l10n.enquiryFlowRecordMeasurementAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.onRemove,
  });

  final XFile photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppPlaceholder.rowHeight,
      height: AppPlaceholder.rowHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: FutureBuilder<Uint8List>(
              future: photo.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data != null &&
                    snapshot.data!.isNotEmpty) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  );
                }
                return Center(
                  child: Icon(
                    AppIcons.image,
                    size: AppIconSize.normal,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: AppSpacing.xxs,
            right: AppSpacing.xxs,
            child: Material(
              color: theme.colorScheme.scrim.withValues(
                alpha: AppTint.shimmerRest,
              ),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Icon(
                    AppIcons.close,
                    size: AppIconSize.dense,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── STEP 3: PROPOSAL (QUOTATION) ─────────────────────────────────────────────

class _Step3ProposalSection extends ConsumerStatefulWidget {
  const _Step3ProposalSection({required this.data});

  final EnquiryFlowPipelineData data;

  @override
  ConsumerState<_Step3ProposalSection> createState() =>
      _Step3ProposalSectionState();
}

class _Step3ProposalSectionState extends ConsumerState<_Step3ProposalSection> {
  final _itemCodeController = TextEditingController();
  final _descController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _itemCodeController.text =
        widget.data.capture.productHint ?? 'Мебель на заказ';
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final itemCode = _itemCodeController.text.trim();
    if (itemCode.isEmpty) {
      setState(() => _errorMessage = l10n.enquiryFlowItemCode);
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 1.0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(enquiryFlowActionsProvider)
          .draftProposal(
            captureId: widget.data.capture.id,
            enquiry: widget.data.enquiryId!,
            items: [
              ProposalItem(
                itemCode: itemCode,
                qty: qty,
                rate: rate,
                description: _descController.text.trim(),
              ),
            ],
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
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
  void dispose() {
    _itemCodeController.dispose();
    _descController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEnabled = widget.data.isEnquiryCreated;
    final isDone = widget.data.isQuotationDrafted;

    if (!isEnabled) {
      return AppCard(
        child: Opacity(
          opacity: AppTint.shimmerRest,
          child: Row(
            children: [
              const Icon(AppIcons.quote),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '3. ${l10n.enquiryFlowStep3}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Entrance(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('3. ${l10n.enquiryFlowStep3}'),
                StatusChip(
                  label: isDone ? l10n.qDraft : l10n.qOpen,
                  intent: isDone ? StatusIntent.success : StatusIntent.info,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isDone) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${l10n.enquiryFlowStep3}: '
                  '${widget.data.quotation?.quotation} · '
                  '${widget.data.quotation?.validTill ?? ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _itemCodeController,
                decoration: InputDecoration(
                  labelText: l10n.enquiryFlowItemCode,
                  hintText: l10n.enquiryFlowItemCodeHint,
                  prefixIcon: const Icon(AppIcons.item),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: l10n.enquiryFlowItemDesc,
                  hintText: l10n.enquiryFlowItemDescHint,
                  prefixIcon: const Icon(AppIcons.task),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.enquiryFlowItemQty,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.enquiryFlowItemRate,
                        prefixIcon: const Icon(AppIcons.deal),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: AppIconSize.small,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.focus,
                        ),
                      )
                    : const Icon(AppIcons.forward),
                label: Text(l10n.enquiryFlowDraftProposalAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── STEP 4: ORDER ────────────────────────────────────────────────────────────

class _Step4OrderSection extends ConsumerStatefulWidget {
  const _Step4OrderSection({required this.data});

  final EnquiryFlowPipelineData data;

  @override
  ConsumerState<_Step4OrderSection> createState() => _Step4OrderSectionState();
}

class _Step4OrderSectionState extends ConsumerState<_Step4OrderSection> {
  DateTime? _deliveryDate;
  String? _errorMessage;
  bool _isSubmitting = false;

  static String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _deliveryDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_deliveryDate == null) {
      setState(() => _errorMessage = l10n.enquiryFlowDeliveryDateRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final dateStr =
        '${_deliveryDate!.year}-'
        '${_deliveryDate!.month.toString().padLeft(2, '0')}-'
        '${_deliveryDate!.day.toString().padLeft(2, '0')}';

    try {
      await ref
          .read(enquiryFlowActionsProvider)
          .acceptOrder(
            captureId: widget.data.capture.id,
            quotation: widget.data.quotation!.quotation,
            deliverOn: dateStr,
          );
      if (mounted) {
        setState(() => _isSubmitting = false);
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
    final isQuotationReady = widget.data.isQuotationDrafted;
    final isDone = widget.data.isOrderAccepted;

    if (!isQuotationReady) {
      return AppCard(
        child: Opacity(
          opacity: AppTint.shimmerRest,
          child: Row(
            children: [
              const Icon(AppIcons.deal),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '4. ${l10n.enquiryFlowStep4}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Entrance(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('4. ${l10n.enquiryFlowStep4}'),
                StatusChip(
                  label: isDone ? l10n.qOrdered : l10n.qOpen,
                  intent: isDone ? StatusIntent.success : StatusIntent.info,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isDone) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: AppTint.surface,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(
                      alpha: AppTint.ornamentOnDark,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.success,
                          color: theme.colorScheme.primary,
                          size: AppIconSize.normal,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.enquiryFlowOrderCompleted,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${l10n.enquiryFlowStep4}: '
                      '${widget.data.order?.salesOrder} · '
                      '${widget.data.order?.deliverOn}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => context.push(Routes.orders),
                      icon: const Icon(AppIcons.forward),
                      label: Text(l10n.enquiryFlowViewOrder),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.schedule),
                title: Text(l10n.enquiryFlowDeliveryDate),
                subtitle: Text(
                  _deliveryDate != null
                      ? '${_deliveryDate!.year}-'
                            '${_pad(_deliveryDate!.month)}-'
                            '${_pad(_deliveryDate!.day)}'
                      : l10n.enquiryFlowDeliveryDateRequired,
                  style: TextStyle(
                    color: _deliveryDate == null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(l10n.enquiryFlowPickDeliveryDate),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _isSubmitting || _deliveryDate == null
                    ? null
                    : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: AppIconSize.small,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.focus,
                        ),
                      )
                    : const Icon(AppIcons.check),
                label: Text(l10n.enquiryFlowAcceptOrderAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
