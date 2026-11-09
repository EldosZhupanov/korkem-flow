/// Dates the way the shop reads them (owner, 09.11.2026): day.month.year.
library;

/// «2026-11-09» → «09.11.2026»; with [year] false, «09.11». Anything that
/// is not a date is shown as it came.
String mdfDay(String? iso, {bool year = true}) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return iso ?? '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return year ? '$dd.$mm.${d.year}' : '$dd.$mm';
}

String mdfDayOf(DateTime d) => mdfDay(mdfIso(d));

/// The server's form: «2026-11-09».
String mdfIso(DateTime d) => d.toIso8601String().substring(0, 10);

/// A due date [days] from [today]; a Sunday — the shop's day off — moves to
/// Monday. A new order's is a week (owner, 09.11.2026).
DateTime mdfDueIn(DateTime today, {int days = 7}) {
  final d = DateTime(today.year, today.month, today.day + days);
  return d.weekday == DateTime.sunday ? d.add(const Duration(days: 1)) : d;
}

/// The quick choices beside the calendar.
const mdfDueQuickDays = [3, 7, 10, 14];
