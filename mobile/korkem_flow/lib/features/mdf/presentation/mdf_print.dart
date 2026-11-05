import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
});

/// One MDF order on an A4 page, the way the owner prints it from OnayBaza
/// («Тапсырыс №36», «№1129»): a head of label / value rows, then the lines
/// — №, note, height, width, pieces, m² — and «Барлығы».
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

  final head = <(String, String)>[
    (words.accepted, order.createdOn),
    (words.due, order.deliveryDate),
    (words.customer, order.customerName),
    (words.phone, order.phone ?? ''),
    (words.thickness, h.thicknessMm == null ? '' : '${h.thicknessMm} мм'),
    (words.finish, h.finish ?? ''),
    (words.decorTop, h.decorTop ?? ''),
    (words.decorBottom, h.decorBottom ?? ''),
    (words.patina, h.patina ?? ''),
    (words.milling, h.milling ?? ''),
    (words.edge, h.edgeProfile ?? ''),
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
    words.note,
    words.height,
    words.width,
    words.qty,
    words.area,
    if (withPrices) words.rate,
    if (withPrices) words.amount,
  ];

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
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(4),
            for (var i = 2; i < columns.length; i++)
              i: const pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [for (final c in columns) text(c, style: bold)],
            ),
            for (var i = 0; i < order.lines.length; i++)
              pw.TableRow(
                children: [
                  text('${i + 1}'),
                  text(
                    [
                      order.lines[i].milling,
                      order.lines[i].note,
                    ].whereType<String>().join(' · '),
                  ),
                  text('${order.lines[i].heightMm}', right: true),
                  text('${order.lines[i].widthMm}', right: true),
                  text('${order.lines[i].qty}', right: true),
                  text(area.format(order.lines[i].areaM2), right: true),
                  if (withPrices)
                    text(money.format(order.lines[i].rateM2), right: true),
                  if (withPrices)
                    text(money.format(order.lines[i].amount), right: true),
                ],
              ),
            pw.TableRow(
              children: [
                text(''),
                text(words.total, style: bold),
                text(''),
                text(''),
                text('${order.pieces}', style: bold, right: true),
                text(area.format(order.areaM2), style: bold, right: true),
                if (withPrices) text(''),
                if (withPrices)
                  text(money.format(order.total), style: bold, right: true),
              ],
            ),
          ],
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
