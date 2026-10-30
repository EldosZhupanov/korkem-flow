import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/crew.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Who made it?» — the crew of a finished job (a facade, a furniture stage)
/// and, optionally, how it is split: each one's share in %, or how much each
/// one made — m² or pieces, as [operation] is paid. Nothing entered means
/// equal shares. The server splits the pay and checks the split adds up.
Future<List<CrewShare>?> pickCrew(
  BuildContext context, {
  required String operation,
}) => showDialog<List<CrewShare>>(
  context: context,
  builder: (_) => _CrewDialog(operation: operation),
);

enum _Split { percent, amount }

class _CrewDialog extends ConsumerStatefulWidget {
  const _CrewDialog({required this.operation});

  final String operation;

  @override
  ConsumerState<_CrewDialog> createState() => _CrewDialogState();
}

class _CrewDialogState extends ConsumerState<_CrewDialog> {
  static const _maxCrew = 5;

  final _picked = <String>{};
  final _values = <String, TextEditingController>{};
  _Split _split = _Split.percent;
  String? _error;

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _value(String user) =>
      _values.putIfAbsent(user, TextEditingController.new);

  /// The unit a split by amount is counted in, or `null` when the operation
  /// has no rate here — then only shares in % are offered.
  String? _unit(AppLocalizations l10n) {
    final rates = ref.watch(pieceRatesProvider).value;
    return switch (rates?.rateTypeFor(widget.operation)) {
      PieceRate.perM2 => l10n.unitSquareMetres,
      PieceRate.perPart => l10n.unitPieces,
      _ => null,
    };
  }

  CrewShare _member(String user, {required bool byAmount}) {
    final value = double.tryParse(_value(user).text.replaceAll(',', '.'));
    return (
      user: user,
      share: byAmount ? null : value,
      qty: byAmount ? value : null,
    );
  }

  void _submit(AppLocalizations l10n, {required bool byAmount}) {
    if (_picked.length < 2) {
      setState(() => _error = l10n.crewTooSmall);
      return;
    }
    final crew = [
      for (final user in _picked) _member(user, byAmount: byAmount),
    ];
    final given = crew.where((m) => (m.share ?? m.qty) != null).toList();
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
    final unit = _unit(l10n);
    final byAmount = unit != null && _split == _Split.amount;
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
              if (unit != null) ...[
                SegmentedButton<_Split>(
                  key: const ValueKey('crewSplit'),
                  segments: [
                    ButtonSegment(
                      value: _Split.percent,
                      label: Text(l10n.crewSplitPercent),
                    ),
                    ButtonSegment(
                      value: _Split.amount,
                      label: Text(l10n.crewSplitByAmount(unit)),
                    ),
                  ],
                  selected: {_split},
                  onSelectionChanged: (choice) => setState(() {
                    _split = choice.single;
                    _error = null;
                    for (final c in _values.values) {
                      c.clear();
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(byAmount ? l10n.crewHintAmount : l10n.crewHint),
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
                          controller: _value(person.user),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9.,]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            suffixText: byAmount ? unit : '%',
                          ),
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
          onPressed: () => _submit(l10n, byAmount: byAmount),
          child: Text(l10n.crewDone),
        ),
      ],
    );
  }
}
