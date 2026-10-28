import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/facade_jobs/domain/facade_job.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Who made it?» — the crew of a finished facade and, optionally, each
/// one's share in %. Empty shares mean equal ones; the server splits the pay
/// and checks the shares add up to 100.
Future<List<CrewShare>?> pickCrew(BuildContext context) =>
    showDialog<List<CrewShare>>(
      context: context,
      builder: (_) => const _CrewDialog(),
    );

class _CrewDialog extends ConsumerStatefulWidget {
  const _CrewDialog();

  @override
  ConsumerState<_CrewDialog> createState() => _CrewDialogState();
}

class _CrewDialogState extends ConsumerState<_CrewDialog> {
  static const _maxCrew = 5;

  final _picked = <String>{};
  final _shares = <String, TextEditingController>{};
  String? _error;

  @override
  void dispose() {
    for (final c in _shares.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _share(String user) =>
      _shares.putIfAbsent(user, TextEditingController.new);

  void _submit(AppLocalizations l10n) {
    if (_picked.length < 2) {
      setState(() => _error = l10n.crewTooSmall);
      return;
    }
    final crew = <CrewShare>[
      for (final user in _picked)
        (
          user: user,
          share: double.tryParse(_share(user).text.replaceAll(',', '.')),
        ),
    ];
    final given = crew.where((m) => m.share != null).toList();
    if (given.isNotEmpty && given.length != crew.length) {
      setState(() => _error = l10n.crewSharesAllOrNone);
      return;
    }
    Navigator.of(context).pop(crew);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workers = ref.watch(workersProvider);
    return AlertDialog(
      title: Text(l10n.crewTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: workers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(workersProvider),
          ),
          data: (people) => ListView(
            shrinkWrap: true,
            children: [
              Text(l10n.crewHint),
              const SizedBox(height: AppSpacing.sm),
              for (final person in people)
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        key: ValueKey('crew:${person.user}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(person.name),
                        value: _picked.contains(person.user),
                        onChanged:
                            !_picked.contains(person.user) &&
                                _picked.length >= _maxCrew
                            ? null
                            : (on) => setState(() {
                                _error = null;
                                if (on ?? false) {
                                  _picked.add(person.user);
                                } else {
                                  _picked.remove(person.user);
                                }
                              }),
                      ),
                    ),
                    if (_picked.contains(person.user))
                      SizedBox(
                        width: AppFieldWidth.percent,
                        child: TextField(
                          key: ValueKey('crewShare:${person.user}'),
                          controller: _share(person.user),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(suffixText: '%'),
                        ),
                      ),
                  ],
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('crewDone'),
          onPressed: () => _submit(l10n),
          child: Text(l10n.crewDone),
        ),
      ],
    );
  }
}
