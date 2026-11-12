import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Words on the printed order, in the reader's language.
typedef MdfPrintWords = ({
  String Function(String name) title,
  String accepted,
  String due,
  String customer,
  String phone,
  String thickness,
  String finish,
  String decorTop,
  String decorBottom,
  String patina,
  String milling,
  String edge,
  String extraName,
  String paid,
  String debt,
  String note,
  String height,
  String width,
  String qty,
  String area,
  String rate,
  String amount,
  String total,
  String material,
  String film,
  String back,
  String subtotal,

  /// The R column: a position's edge radius (R0 — a sharp corner, in bold).
  String radius,

  /// «Толщина» as a column head (thickness and material apart, 09.11.2026).
  String thicknessColumn,

  /// A group's coating type by name: ПВХ, краска, черновой.
  String Function(MdfCoating coating) coating,

  /// «Матер.» — the material column's short head (09.11.2026: full words
  /// broke letter by letter in narrow columns).
  String materialColumn,

  /// «шт» in a group's and the order's total line.
  String pieces,

  /// «Метки» — the head's row of the order's tags, and a tag by name.
  String tags,
  String Function(MdfOrderTag tag) tag,

  /// The due date's weekday by name — «четверг» under it in the stamp.
  String Function(DateTime day) weekday,
});

/// One MDF order on an A4 page, the way the owner prints it from OnayBaza
/// («Тапсырыс №36», «№1129»): a head of label / value rows, then the lines
/// — №, height, width, pieces, milling, R, film, material, m² — and
/// «Барлығы». The back side and a patina are written under the film.
///
/// [withPrices] is the customer's copy («Тапсырыс_Клиент»): the price and
/// amount columns, what was paid and what is left. Without it, it is the
/// shop's copy («Тапсырыс_Цех»): no money at all, the order's QR code, and
/// sizes in larger type for the floor. Black on white for a monochrome
/// printer.
Future<Uint8List> buildMdfOrderPdf(
  MdfOrder order,
  MdfPrintWords words, {
  required bool withPrices,
  String locale = 'ru',
  Map<String, String> filmNotes = const {},
  void Function(pw.Document doc)? more,
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  final doc = pw.Document(
    // The bundled Inter has no italic face: without naming it for italics
    // too, the PDF falls back to a font with no Cyrillic and prints boxes
    // (10.11.2026, the note and «итого группы»).
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    ),
  );
  final money = NumberFormat.decimalPattern(locale);
  final area = NumberFormat('0.00', locale);
  final size = withPrices ? 10.0 : 12.0;
  final cell = pw.TextStyle(fontSize: size);
  final bold = pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold);
  final small = pw.TextStyle(fontSize: size - 2);
  // A size up on the shop's copy only: the customer's has two more
  // columns, and «2000» broke in two there (10.11.2026).
  final sizes = pw.TextStyle(
    fontSize: withPrices ? size : size + 1.5,
    fontWeight: pw.FontWeight.bold,
  );
  final h = order.head;

  final groups = mdfFilmGroups(order.lines);
  // The head says what the positions have, every kind of it (owner,
  // 09.11.2026): «16 мм, 18 мм», all the coatings, «R3, R0» — the order's
  // defaults only where no position says.
  String all(
    Iterable<String?> values,
    String? fallback, {
    bool sorted = false,
  }) {
    final kinds = <String>{
      for (final v in values)
        if (v != null && v.isNotEmpty) v,
    }.toList();
    if (sorted) kinds.sort(mdfNaturalCompare);
    final seen = kinds.join(', ');
    return seen.isNotEmpty ? seen : fallback ?? '';
  }

  // Срочный, гарантия, переделка: framed under the order's number on both
  // copies. The black band over the shop's copy is gone (owner, 10.11.2026:
  // «под заказом достаточно»).
  final tagNames = [for (final t in order.tags) words.tag(t)];
  final thicknesses = {
    for (final l in order.lines) ?l.thicknessMm,
  }.toList()..sort();
  // Variant 2 (owner, 10.11.2026): the due date is a stamp of its own and
  // the tags sit framed under the number, so the head is pairs — the
  // customer and the phone, paid and owed — five rows where it was eleven.
  final head = <(String, String)>[
    (words.customer, order.customerName),
    (words.phone, order.phone ?? ''),
    (words.accepted, mdfDay(order.createdOn)),
    (
      words.thickness,
      all(
        [for (final t in thicknesses) '$t мм'],
        h.thicknessMm == null ? null : '${h.thicknessMm} мм',
      ),
    ),
    (
      words.material,
      all(
        [for (final l in order.lines) l.material],
        h.material,
        sorted: true,
      ),
    ),
    (
      words.film,
      all([
        for (final g in groups) _groupName(words, g.coating, g.film),
      ], h.finish),
    ),
    if (h.patina != null) (words.patina, h.patina!),
    if (h.milling != null) (words.milling, h.milling!),
    // R0, R1, R3, R5, then the named edges by alphabet (owner, 09.11.2026).
    (
      words.radius,
      all(
        [for (final l in order.lines) l.edge],
        h.edgeProfile,
        sorted: true,
      ),
    ),
    if (h.extraName != null) (words.extraName, h.extraName!),
    if (withPrices) (words.paid, '${money.format(order.paid)} ₸'),
    if (withPrices) (words.debt, '${money.format(order.debt)} ₸'),
  ];

  pw.Widget text(String value, {pw.TextStyle? style, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          value,
          style: style ?? cell,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );

  final columns = [
    '№',
    words.height,
    words.width,
    words.qty,
    words.milling,
    words.radius,
    words.film,
    words.thicknessColumn,
    words.materialColumn,
    words.area,
    if (withPrices) words.rate,
    if (withPrices) words.amount,
  ];
  // The film's colour, pale enough to print text over and to survive a
  // monochrome printer as a grey band; the film is named in words as well.
  PdfColor tint(int g) {
    final c = AppColors.filmGroup(g);
    double pale(double v) => 1 - (1 - v) * 0.2;
    return PdfColor(pale(c.r), pale(c.g), pale(c.b));
  }

  pw.TableRow lineRow(int n, MdfLine l, int g) => pw.TableRow(
    decoration: pw.BoxDecoration(color: tint(g)),
    children: [
      text('$n'),
      // The sizes are what the shop works by (owner, 10.11.2026): bold
      // and a size up; the rest of the row stays plain.
      text('${l.heightMm}', right: true, style: sizes),
      text('${l.widthMm}', right: true, style: sizes),
      text('${l.qty}', right: true, style: sizes),
      text(l.milling ?? ''),
      // Any edge but the usual R3 in bold: the shop must not miss it.
      text(
        l.edge ?? '',
        style: l.edge != null && l.edge != mdfDefaultEdge ? bold : null,
      ),
      // Variant А (owner, 10.11.2026): the back side and a patina are the
      // colour of the part, so they sit under the coating, smaller.
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_groupName(words, l.coating, l.film), style: cell),
            for (final x in mdfCoatingExtras(
              l,
              back: words.back,
              patina: words.patina,
            ))
              pw.Text(x, style: small),
          ],
        ),
      ),
      text(l.thicknessMm == null ? '' : '${l.thicknessMm} мм', right: true),
      text(l.material ?? ''),
      text(area.format(l.areaM2), right: true),
      if (withPrices) text(money.format(l.rateM2), right: true),
      if (withPrices) text(money.format(l.amount), right: true),
    ],
  );

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(24),
    1: const pw.FlexColumnWidth(1.1),
    2: const pw.FlexColumnWidth(1.1),
    // «Кол.» and «м²» a little wider (owner, 10.11.2026): the header «Кол.»
    // and the order's «14,20» broke in two on the customer's copy.
    3: const pw.FlexColumnWidth(),
    4: const pw.FlexColumnWidth(2.4),
    5: const pw.FlexColumnWidth(1.5),
    6: const pw.FlexColumnWidth(3),
    7: const pw.FlexColumnWidth(1.3),
    8: const pw.FlexColumnWidth(1.4),
    9: const pw.FlexColumnWidth(1.3),
    if (withPrices) 10: const pw.FlexColumnWidth(1.5),
    if (withPrices) 11: const pw.FlexColumnWidth(1.8),
  };
  // A total under its own columns (owner, 10.11.2026): pieces under
  // «Кол», m² under «м²», money under «Сумма». A group's is near black,
  // smaller, its label in italics; the order's is large and bold under a
  // thick rule.
  pw.Widget sumRow(
    String label,
    int pieces,
    double m2,
    double amount, {
    bool order = false,
  }) {
    final style = order
        // Larger on the shop's copy; on the customer's, with two money
        // columns, «363 780» must stay on one line.
        ? pw.TextStyle(
            fontSize: withPrices ? size + 0.5 : size + 2,
            fontWeight: pw.FontWeight.bold,
          )
        : pw.TextStyle(fontSize: size - 1, color: PdfColors.grey800);
    final line = pw.BorderSide(width: order ? 2 : 0.5);
    pw.Widget cell(String v, int flex) => pw.Expanded(
      flex: flex,
      child: text(v, style: style, right: true),
    );
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: const pw.BorderSide(width: 0.5),
          right: const pw.BorderSide(width: 0.5),
          bottom: const pw.BorderSide(width: 0.5),
          top: order ? line : pw.BorderSide.none,
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 24),
          pw.Expanded(
            flex: 22,
            child: text(
              label,
              style: order
                  ? style
                  : pw.TextStyle(
                      fontSize: size - 1,
                      color: PdfColors.grey800,
                      fontStyle: pw.FontStyle.italic,
                    ),
            ),
          ),
          // The number alone, under «Кол.»: «шт» broke the narrow column.
          cell('$pieces', 10),
          pw.Spacer(flex: 24 + 15 + 30 + 13 + 14),
          cell(area.format(m2), 13),
          if (withPrices) pw.Spacer(flex: 15),
          if (withPrices) cell(money.format(amount), 18),
        ],
      ),
    );
  }

  // The coating's name over its positions, across the page (owner,
  // 10.11.2026): where «Белый Матовый» begins is seen before its rows.
  pw.Widget groupHead(MdfFilmGroup group, int g) {
    final c = AppColors.filmGroup(g);
    double mid(double v) => 1 - (1 - v) * 0.45;
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColor(mid(c.r), mid(c.g), mid(c.b)),
        border: const pw.Border(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
        ),
      ),
      child: text(
        [
          _groupName(words, group.coating, group.film),
          // The film it takes on the press (owner, 12.11.2026).
          ?filmNotes[group.film],
        ].join('   ·   '),
        style: pw.TextStyle(fontSize: size + 1, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Table rows(List<pw.TableRow> children) => pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: widths,
    children: children,
  );

  // A position's note on a line of its own under it (owner, 10.11.2026,
  // variant А): a dashed line from «Выс.» to the edge, the № cell running
  // on through it — one position, two lines.
  List<pw.Widget> groupLines(MdfFilmGroup group, int g) {
    final out = <pw.Widget>[];
    var pending = <pw.TableRow>[];
    for (final (n, l) in group.lines) {
      pending.add(lineRow(n, l, g));
      final note = mdfLineNote(l);
      if (note == null) continue;
      out
        ..add(
          pw.Table(
            border: const pw.TableBorder(
              left: pw.BorderSide(width: 0.5),
              right: pw.BorderSide(width: 0.5),
              top: pw.BorderSide(width: 0.5),
              horizontalInside: pw.BorderSide(width: 0.5),
              verticalInside: pw.BorderSide(width: 0.5),
            ),
            columnWidths: widths,
            children: pending,
          ),
        )
        ..add(
          pw.Container(
            decoration: pw.BoxDecoration(
              color: tint(g),
              border: const pw.Border(
                left: pw.BorderSide(width: 0.5),
                right: pw.BorderSide(width: 0.5),
                bottom: pw.BorderSide(width: 0.5),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 24,
                  height: 16,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(width: 0.5)),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          width: 0.6,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                    child: text(
                      '${words.note}: $note',
                      style: pw.TextStyle(
                        fontSize: size - 1,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      pending = [];
    }
    if (pending.isNotEmpty) out.add(rows(pending));
    return out;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    words.title(order.name),
                    style: const pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (tagNames.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in tagNames)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(width: 1.5),
                            ),
                            child: pw.Text(
                              t.toUpperCase(),
                              style: const pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _dueStamp(order.deliveryDate, words),
            if (!withPrices) pw.SizedBox(width: 8),
            if (!withPrices)
              pw.SizedBox(
                width: 64,
                height: 64,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: order.name,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        for (final (i, row) in _pairs(
          head,
          film: words.film,
          paid: words.paid,
        ).indexed)
          pw.Table(
            border: pw.TableBorder(
              left: const pw.BorderSide(width: 0.5),
              right: const pw.BorderSide(width: 0.5),
              bottom: const pw.BorderSide(width: 0.5),
              top: i == 0
                  ? const pw.BorderSide(width: 0.5)
                  : pw.BorderSide.none,
              verticalInside: const pw.BorderSide(width: 0.5),
            ),
            columnWidths: row.length == 1
                ? const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(8)}
                : const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(3),
                  },
            children: [
              pw.TableRow(
                children: [
                  for (final (label, value) in row) ...[
                    text(label),
                    text(value, style: bold),
                  ],
                ],
              ),
            ],
          ),
        pw.SizedBox(height: 10),
        rows([
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [for (final c in columns) text(c, style: bold)],
          ),
        ]),
        for (final (g, group) in groups.indexed) ...[
          groupHead(group, g),
          ...groupLines(group, g),
          if (groups.length > 1)
            sumRow(
              words.subtotal.toLowerCase(),
              group.pieces,
              group.areaM2,
              group.amount,
            ),
        ],
        sumRow(
          words.total.replaceAll(':', '').toUpperCase(),
          order.pieces,
          order.areaM2,
          order.total,
          order: true,
        ),
      ],
    ),
  );
  more?.call(doc);
  return doc.save();
}

Future<void> printMdfOrder({
  required String name,
  required Future<Uint8List> Function() build,
}) => Printing.layoutPdf(name: name, onLayout: (_) => build());

/// The head's rows: two pairs side by side, the coatings — the longest —
/// across the whole width.
List<List<(String, String)>> _pairs(
  List<(String, String)> head, {
  required String film,
  required String paid,
}) {
  final out = <List<(String, String)>>[];
  (String, String)? left;
  for (final item in head) {
    if (item.$1 == film) {
      out.add([item]);
      continue;
    }
    // Paid and owed always side by side.
    if (item.$1 == paid && left != null) {
      out.add([left]);
      left = null;
    }
    if (left == null) {
      left = item;
    } else {
      out.add([left, item]);
      left = null;
    }
  }
  if (left != null) out.add([left]);
  return out;
}

/// «СРОК 13.11.2026 четверг» in a thick frame: the date the shop works to,
/// seen before anything else on the page (owner, 10.11.2026).
pw.Widget _dueStamp(String due, MdfPrintWords words) {
  final day = DateTime.tryParse(due);
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 2.5)),
    child: pw.Column(
      children: [
        pw.Text(
          words.due.toUpperCase(),
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          mdfDay(due),
          style: const pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (day != null)
          pw.Text(
            words.weekday(day),
            style: const pw.TextStyle(fontSize: 9),
          ),
      ],
    ),
  );
}

/// What a position's coating has besides its colour — «Обр.: Графит»,
/// «Патина: Золотой» — a line each under it, on the card and the printout.
List<String> mdfCoatingExtras(
  MdfLine l, {
  required String back,
  required String patina,
}) => [
  if (l.filmBack != null) '${_capital(back)}: ${l.filmBack}',
  if (l.patina != null) '${_capital(patina)}: ${l.patina}',
];

/// A position's note, or null when it has none.
String? mdfLineNote(MdfLine l) {
  final note = l.note?.trim();
  return note == null || note.isEmpty ? null : note;
}

String _capital(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _groupName(MdfPrintWords words, MdfCoating? coating, String? film) => [
  if (coating != null) words.coating(coating),
  ?film,
].join(' · ');
