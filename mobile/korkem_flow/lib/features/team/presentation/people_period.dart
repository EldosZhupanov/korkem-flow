import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// Tenge, no kopecks.
NumberFormat peopleMoney(BuildContext context) => NumberFormat.currency(
  locale: _locale(context),
  symbol: '₸',
  decimalDigits: 0,
);

/// «4,25 м²» — no trailing zeros.
String peopleM2(BuildContext context, double v) =>
    '${NumberFormat('0.##', _locale(context)).format(v)} м²';

/// «25 ноября 2026», «23 нояб. – 29 нояб.», «ноябрь 2026».
String peopleSpanLabel(BuildContext context, PeopleSpan span, DateTime day) {
  final locale = _locale(context);
  final (from, to) = peopleSpanOf(span, day);
  return switch (span) {
    PeopleSpan.day => DateFormat.yMMMMd(locale).format(from),
    PeopleSpan.week =>
      '${DateFormat.MMMd(locale).format(from)} – '
          '${DateFormat.MMMd(locale).format(to)}',
    PeopleSpan.month => DateFormat.yMMMM(locale).format(from),
  };
}

/// День · Неделя · Месяц, and ‹ the period › under it. The future is not
/// offered: nothing has been done in it yet.
class PeoplePeriodBar extends StatelessWidget {
  const PeoplePeriodBar({
    required this.span,
    required this.day,
    required this.today,
    required this.onChanged,
    this.monthOnly = false,
    super.key,
  });

  final PeopleSpan span;
  final DateTime day;
  final DateTime today;
  final void Function(PeopleSpan span, DateTime day) onChanged;

  /// Money is counted by the month: no day or week to choose.
  final bool monthOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (_, end) = peopleSpanOf(span, day);
    final now = DateTime(today.year, today.month, today.day);
    return Column(
      children: [
        if (!monthOnly)
          SegmentedButton<PeopleSpan>(
          key: const ValueKey('ppl:span'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: PeopleSpan.day, label: Text(l10n.pplDay)),
            ButtonSegment(value: PeopleSpan.week, label: Text(l10n.pplWeek)),
            ButtonSegment(value: PeopleSpan.month, label: Text(l10n.pplMonth)),
          ],
          selected: {span},
          onSelectionChanged: (s) => onChanged(s.first, day),
        ),
        if (!monthOnly) const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('ppl:prev'),
              tooltip: l10n.pplPrev,
              onPressed: () => onChanged(span, peopleShift(span, day, -1)),
              icon: const Icon(AppIcons.previous),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Text(
                  peopleSpanLabel(context, span, day),
                  key: const ValueKey('ppl:period'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('ppl:next'),
              tooltip: l10n.pplNext,
              onPressed: end.isBefore(now)
                  ? () => onChanged(span, peopleShift(span, day, 1))
                  : null,
              icon: const Icon(AppIcons.forward),
            ),
          ],
        ),
      ],
    );
  }
}
