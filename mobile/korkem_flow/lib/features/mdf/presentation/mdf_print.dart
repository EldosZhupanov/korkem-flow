import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
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
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final money = NumberFormat.decimalPattern(locale);
  final area = NumberFormat('0.00', locale);
  final size = withPrices ? 10.0 : 12.0;
  final cell = pw.TextStyle(fontSize: size);
  final bold = pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold);
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

  final thicknesses = {
    for (final l in order.lines) ?l.thicknessMm,
  }.toList()..sort();
  final head = <(String, String)>[
    (words.accepted, order.createdOn),
    (words.due, order.deliveryDate),
    (words.customer, order.customerName),
    (words.phone, order.phone ?? ''),
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
    if (withPrices) (words.paid, money.format(order.paid)),
    if (withPrices) (words.debt, money.format(order.debt)),
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
      text('${l.heightMm}', right: true),
      text('${l.widthMm}', right: true),
      text('${l.qty}', right: true),
      text([l.milling, l.note].whereType<String>().join(' · ')),
      // Any edge but the usual R3 in bold: the shop must not miss it.
      text(
        l.edge ?? '',
        style: l.edge != null && l.edge != mdfDefaultEdge ? bold : null,
      ),
      text(
        [
          _groupName(words, l.coating, l.film),
          if (l.filmBack != null) '+ ${words.back}: ${l.filmBack}',
          if (l.patina != null) '+ ${words.patina}: ${l.patina}',
        ].join('\n'),
      ),
      text(l.thicknessMm == null ? '' : '${l.thicknessMm} мм', right: true),
      text(l.material ?? ''),
      text(area.format(l.areaM2), right: true),
      if (withPrices) text(money.format(l.rateM2), right: true),
      if (withPrices) text(money.format(l.amount), right: true),
    ],
  );

  // A total on one line across the page, not squeezed into a column.
  pw.Widget sumLine(String label, int pieces, double m2, double amount) =>
      pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(width: 0.5),
            right: pw.BorderSide(width: 0.5),
            bottom: pw.BorderSide(width: 0.5),
          ),
        ),
        child: text(
          [
            '$label: $pieces ${words.pieces}',
            '${area.format(m2)} м²',
            if (withPrices) money.format(amount),
          ].join(' · '),
          style: bold,
        ),
      );

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(24),
    1: const pw.FlexColumnWidth(1.1),
    2: const pw.FlexColumnWidth(1.1),
    3: const pw.FlexColumnWidth(0.9),
    4: const pw.FlexColumnWidth(2.6),
    5: const pw.FlexColumnWidth(1.5),
    6: const pw.FlexColumnWidth(3),
    7: const pw.FlexColumnWidth(1.3),
    8: const pw.FlexColumnWidth(1.4),
    9: const pw.FlexColumnWidth(1.2),
    if (withPrices) 10: const pw.FlexColumnWidth(1.5),
    if (withPrices) 11: const pw.FlexColumnWidth(1.8),
  };
  pw.Table rows(List<pw.TableRow> children) => pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    columnWidths: widths,
    children: children,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                words.title(order.name),
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
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
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            for (final (label, value) in head)
              pw.TableRow(
                children: [
                  text(label),
                  text(value, style: bold),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        rows([
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [for (final c in columns) text(c, style: bold)],
          ),
        ]),
        for (final (g, group) in groups.indexed) ...[
          rows([for (final (n, l) in group.lines) lineRow(n, l, g)]),
          if (groups.length > 1)
            sumLine(
              '${words.subtotal} '
              '${_groupName(words, group.coating, group.film)}',
              group.pieces,
              group.areaM2,
              group.amount,
            ),
        ],
        sumLine(
          words.total.replaceAll(':', ''),
          order.pieces,
          order.areaM2,
          order.total,
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> printMdfOrder({
  required String name,
  required Future<Uint8List> Function() build,
}) => Printing.layoutPdf(name: name, onLayout: (_) => build());

String _groupName(MdfPrintWords words, MdfCoating? coating, String? film) => [
  if (coating != null) words.coating(coating),
  ?film,
].join(' · ');

/// «R0» before «R3» before «R10», and words after them by alphabet: a
/// run of digits compares as a number.
int mdfNaturalCompare(String a, String b) {
  final digits = RegExp(r'\d+');
  final ma = digits.firstMatch(a);
  final mb = digits.firstMatch(b);
  final pa = ma == null ? a : a.substring(0, ma.start);
  final pb = mb == null ? b : b.substring(0, mb.start);
  if (ma != null && mb != null && pa == pb) {
    final byNumber = int.parse(ma[0]!).compareTo(int.parse(mb[0]!));
    if (byNumber != 0) return byNumber;
  }
  // Latin «R…» before Cyrillic words: code units already order them so.
  return a.toLowerCase().compareTo(b.toLowerCase());
}
