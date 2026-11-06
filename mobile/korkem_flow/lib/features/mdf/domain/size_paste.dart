import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

/// Lines out of whatever the manager pasted — a WhatsApp message, Excel
/// cells, a photo's transcript, an old order form.
///
/// One facade per line, written the way people write them:
///
///     348 997 2
///     348х997 - 2шт
///     2027*497*4
///     1577 × 517 (2)
///     348	997	2	Ойықталған 16-14      ← Excel: tabs, then a note
///     130 на 1040
///
/// The first two numbers are height and width in millimetres, the third, if
/// there is one, the pieces (one otherwise). Whatever words follow become
/// the line's note. A line with fewer than two numbers is skipped and
/// reported, never guessed: a wrong size costs a sheet of MDF.
SizePaste parseSizes(String text, {String? milling}) {
  final lines = <MdfLineInput>[];
  final skipped = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final row = raw.trim();
    if (row.isEmpty) continue;
    final numbers = _number.allMatches(row).toList();
    if (numbers.length < 2) {
      skipped.add(row);
      continue;
    }
    int? value(int i) => i < numbers.length
        ? double.tryParse(numbers[i].group(0)!.replaceAll(',', '.'))?.round()
        : null;
    final height = value(0)!;
    final width = value(1)!;
    final third = value(2);
    // A third number is the pieces only while it looks like a count; «16-14»
    // in a note is a milling, not 16 pieces.
    final qtyIsCount =
        third != null &&
        third > 0 &&
        third < 1000 &&
        !_partOfNote(row, numbers);
    final noteFrom = (qtyIsCount ? numbers[2] : numbers[1]).end;
    final note = row.substring(noteFrom).replaceFirst(_countTail, '').trim();
    if (height < 10 || width < 10 || height > 3000 || width > 3000) {
      skipped.add(row);
      continue;
    }
    lines.add(
      MdfLineInput(
        heightMm: height,
        widthMm: width,
        qty: qtyIsCount ? third : 1,
        milling: milling,
        note: note.isEmpty ? null : note,
      ),
    );
  }
  return (lines: lines, skipped: skipped);
}

typedef SizePaste = ({List<MdfLineInput> lines, List<String> skipped});

final _number = RegExp(r'\d+(?:[.,]\d+)?');

/// What follows a count: «шт», «дана», brackets, dashes — not the note.
final _countTail = RegExp(
  r'^[\s\-–—:;,.)(*]*(шт\.?|pcs|дана)?[\s)(.,;:-]*',
  caseSensitive: false,
);

/// «348 997 Ойықталған 16-14»: the 16 sits after a word, so it belongs to the
/// note. «348 997 2шт» or «348х997-2»: it sits right after the sizes.
bool _partOfNote(String row, List<RegExpMatch> numbers) {
  final between = row.substring(numbers[1].end, numbers[2].start);
  return RegExp('[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі]{2,}').hasMatch(between);
}
