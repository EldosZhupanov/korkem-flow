import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_ready.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Срок» (owner, 27.11.2026): the month by the shop's load, «надёжно» and
/// «впритык», and the film the order waits for. A day is picked — or
/// `DateTime(0)`: the plain calendar, when the shop cannot be asked.
Future<DateTime?> showMdfDuePicker(
  BuildContext context, {
  required Future<MdfDueOptions> Function() load,
  required double areaM2,
  DateTime? current,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _DueDialog(
    load: Future.sync(load),
    areaM2: areaM2,
    current: current,
  ),
);

/// How full a day may be before it is «плотно», and «перегруз».
const double _busy = 0.8;
const double _over = 1.2;

class _DueDialog extends StatefulWidget {
  const _DueDialog({required this.load, required this.areaM2, this.current});

  final Future<MdfDueOptions> load;
  final double areaM2;
  final DateTime? current;

  @override
  State<_DueDialog> createState() => _DueDialogState();
}

class _DueDialogState extends State<_DueDialog> {
  DateTime? _picked;
  DateTime? _month;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<MdfDueOptions>(
      future: widget.load,
      builder: (context, snap) {
        if (snap.hasError) {
          // The shop could not be asked: the plain calendar, said so.
          return AlertDialog(
            title: Text(l10n.mdfDue),
            content: Text(l10n.mdfDueNoLoad),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('mdfDueCalendar'),
                onPressed: () => Navigator.of(context).pop(DateTime(0)),
                child: Text(l10n.mdfDueCalendar),
              ),
            ],
          );
        }
        final o = snap.data;
        if (o == null) {
          return const AlertDialog(
            content: SizedBox(
              height: AppSpacing.xxxl * 2,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return _body(context, o);
      },
    );
  }

  Widget _body(BuildContext context, MdfDueOptions o) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final picked = _picked ?? _day(widget.current ?? o.safe);
    final month = _month ?? DateTime(picked.year, picked.month);
    final earliest = _day(o.earliest);
    String m2(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    Color? colour(DateTime d) {
      if (d.weekday == DateTime.sunday) return null;
      if (d.isBefore(earliest))
        return theme.colorScheme.surfaceContainerHighest;
      final cap = o.capacityM2;
      if (cap == null || cap <= 0)
        return status.success.withValues(alpha: AppTint.surface);
      final share = o.dueOn(d) / cap;
      return (share >= _over
              ? status.danger
              : share >= _busy
              ? status.warning
              : status.success)
          .withValues(alpha: AppTint.pressPart);
    }

    // The selected day said in words: too soon, too full, or fine.
    final due = o.dueOn(picked);
    final cap = o.capacityM2;
    final String? warn = picked.isBefore(earliest)
        ? l10n.mdfDueTooSoon(mdfDayOf(earliest))
        : cap != null && due + widget.areaM2 > cap * _over
        ? l10n.mdfDueOverloaded(m2(due), m2(cap), m2(due + widget.areaM2))
        : null;
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    Widget choice(
      String key,
      String label,
      DateTime day,
      Color colour,
      String note,
    ) {
      final on = _day(day) == picked;
      return Expanded(
        child: InkWell(
          key: ValueKey(key),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => setState(() {
            _picked = _day(day);
            _month = DateTime(day.year, day.month);
          }),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: on ? colour : theme.colorScheme.outlineVariant,
                width: on ? AppStroke.focus : AppStroke.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: colour),
                ),
                Text(
                  DateFormat('EE, d MMMM', locale).format(day),
                  style: theme.textTheme.titleMedium,
                ),
                Text(note, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      key: const ValueKey('mdfDueDialog'),
      title: Row(
        children: [
          Expanded(child: Text(l10n.mdfDueTitle(m2(widget.areaM2)))),
          IconButton(
            key: const ValueKey('mdfDuePrev'),
            icon: const Icon(AppIcons.previous),
            onPressed: () =>
                setState(() => _month = DateTime(month.year, month.month - 1)),
          ),
          Text(DateFormat('LLLL y', locale).format(month)),
          IconButton(
            key: const ValueKey('mdfDueNext'),
            icon: const Icon(AppIcons.forward),
            onPressed: () =>
                setState(() => _month = DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 11,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The film it waits for: the date counts from its coming.
              for (final f in o.films)
                if (f.short)
                  Container(
                    key: ValueKey('mdfDueFilm:${f.decor}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: status.info.withValues(alpha: AppTint.surface),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      f.comesOn == null
                          ? l10n.mdfDueFilmUnknown(f.decor)
                          : l10n.mdfDueFilmComes(
                              f.decor,
                              f.supplier ?? '',
                              mdfDayOf(f.comesOn!),
                            ),
                    ),
                  ),
              Row(
                children: [
                  choice(
                    'mdfDueSafe',
                    l10n.mdfDueSafe,
                    o.safe,
                    status.success,
                    l10n.mdfDueSafeNote,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  choice(
                    'mdfDueByShop',
                    l10n.mdfDueEarliest,
                    o.earliest,
                    status.warning,
                    o.known ? l10n.mdfDueEarliestNote : l10n.mdfDueRough,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.xxs,
                crossAxisSpacing: AppSpacing.xxs,
                childAspectRatio: 1.2,
                children: [
                  for (var w = 1; w <= 7; w++)
                    Center(
                      child: Text(
                        DateFormat.E(locale).format(DateTime(2026, 11, 22 + w)),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var n = 1; n <= count; n++)
                    () {
                      final d = DateTime(month.year, month.month, n);
                      final load = o.dueOn(d);
                      final sunday = d.weekday == DateTime.sunday;
                      final on = d == picked;
                      return InkWell(
                        key: ValueKey('mdfDueDay:${mdfIso(d)}'),
                        onTap: sunday
                            ? null
                            : () => setState(() => _picked = d),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colour(d),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: on
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: AppStroke.focus,
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          // Scaled down, never cut, on a phone's narrow cell.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$n',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: sunday
                                        ? theme.colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                if (load > 0 && !sunday)
                                  Text(
                                    '${m2(load)} ${l10n.unitSquareMetres}',
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                for (final f in o.films)
                                  if (f.short &&
                                      f.comesOn != null &&
                                      _day(f.comesOn!) == d)
                                    Icon(
                                      AppIcons.delivery,
                                      size: AppIconSize.dense,
                                      color: status.info,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                cap == null
                    ? l10n.mdfDueLegendNoPace
                    : l10n.mdfDueLegend(m2(cap)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (warn != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  warn,
                  key: const ValueKey('mdfDueWarn'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: status.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('mdfDueCalendar'),
          onPressed: () => Navigator.of(context).pop(DateTime(0)),
          child: Text(l10n.mdfDueCalendar),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('mdfDuePick'),
          onPressed: () => Navigator.of(context).pop(picked),
          child: Text(l10n.mdfDuePick(mdfDayOf(picked))),
        ),
      ],
    );
  }
}
