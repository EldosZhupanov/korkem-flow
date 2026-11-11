import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Words on a film sale's receipt, in the reader's language.
typedef FilmReceiptWords = ({
  String title,
  String date,
  String customer,
  String film,
  String metres,
  String price,
  String amount,
  String total,
  String paid,
  String debt,

  /// «Оплата» — how it was paid, part by part (owner, 12.11.2026).
  String payment,

  /// A payment's way in the reader's words: «Наличные», «Перевод».
  String Function(String method) method,

  /// «Продавец (ответственный): …», his phone, and the two signatures.
  String Function(String name) servedBy,
  String Function(String phone) phone,
  String signedSold,
  String signedGot,

  /// «Выдал со склада: …» and its signature (owner, 12.11.2026).
  String Function(String name) issuedBy,
  String signedIssued,

  /// «код 1155 BD», «0,3 мм» — under the film's name.
  String Function(String code) code,
  String Function(double mm) thickness,

  /// A warm word at the foot (owner, 12.11.2026: «отзыв очень приятный
  /// или комплимент»).
  String thanks,
  String wish,
});

/// A film sale's receipt for the customer (owner, 11.11.2026): the films,
/// metres, a metre's price and the sum; what was paid and what is left.
/// Black on white, half an A4 — sent in WhatsApp or printed.
Future<Uint8List> buildFilmReceiptPdf(
  FilmSale sale,
  FilmReceiptWords words, {
  String locale = 'ru',
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  final money = NumberFormat.currency(
    locale: locale,
    symbol: '₸',
    decimalDigits: 0,
  );
  String metres(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    ),
  );
  const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  pw.Widget cell(String text, {pw.TextStyle? style, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Align(
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(text, style: style),
        ),
      );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${words.title} ${sale.entry}',
            style: const pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('${words.date}: ${mdfDay(sale.date)}'),
          if (sale.customerName != null)
            pw.Text('${words.customer}: ${sale.customerName}'),
          pw.SizedBox(height: 12),
          // The film's name, and under it in small grey what it is: maker,
          // code, surface, thickness (owner, 12.11.2026).
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(5),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2.4),
            },
            children: [
              pw.TableRow(
                children: [
                  cell(words.film, style: bold),
                  cell(words.metres, style: bold, right: true),
                  cell(words.price, style: bold, right: true),
                  cell(words.amount, style: bold, right: true),
                ],
              ),
              for (final l in sale.lines)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(l.colour ?? l.title, style: bold),
                          if (_about(l, words) case final about?)
                            pw.Text(
                              about,
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    cell(metres(l.metres), right: true),
                    cell(money.format(l.priceM ?? 0), right: true),
                    cell(
                      money.format(l.metres * (l.priceM ?? 0)),
                      right: true,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '${words.total}: ${money.format(sale.amount ?? 0)}',
                  style: const pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('${words.paid}: ${money.format(sale.paid ?? 0)}'),
                if ((sale.debt ?? 0) > 0)
                  pw.Text(
                    '${words.debt}: ${money.format(sale.debt)}',
                    style: bold,
                  ),
              ],
            ),
          ),
          // How it was paid, part by part: cash, Kaspi …
          if (sale.payments.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(words.payment, style: bold),
            for (final p in sale.payments)
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      [
                        words.method(p.method),
                        ?p.bank,
                        if (p.date != sale.date) mdfDay(p.date),
                      ].join(' · '),
                    ),
                  ),
                  pw.Text(money.format(p.amount)),
                ],
              ),
          ],
          // The seller answers for the sale: name, phone, and a line to sign
          // for each side (owner, 12.11.2026).
          if (sale.seller != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(words.servedBy(sale.seller!), style: bold),
            if (sale.sellerPhone != null)
              pw.Text(words.phone(sale.sellerPhone!)),
          ],
          if (sale.issuedBy != null) pw.Text(words.issuedBy(sale.issuedBy!)),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${words.signedSold}: ___________'),
              pw.Text('${words.signedIssued}: ___________'),
              pw.Text('${words.signedGot}: ___________'),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey600, thickness: 0.5),
          pw.Center(
            child: pw.Text(
              words.thanks,
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              words.wish,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// «код 1155 BD · Матовое эмаль · 0,3 мм · Adilet» — what the film is;
/// where it was bought is not the customer's business.
String? _about(FilmSaleLine l, FilmReceiptWords words) {
  // The maker last (owner, 12.11.2026).
  final parts = [
    if (l.code != null) words.code(l.code!),
    ?l.type,
    if (l.thicknessMm != null) words.thickness(l.thicknessMm!),
    ?l.maker,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Handed on — to WhatsApp, a printer, a file — the way the device does it.
Future<void> shareFilmReceipt(FilmSale sale, Uint8List bytes) =>
    Printing.sharePdf(bytes: bytes, filename: 'chek-${sale.entry}.pdf');
