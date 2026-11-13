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

/// Words on a customer's statement, in the reader's language.
typedef FilmStatementWords = ({
  String title,
  String Function(String name) customer,
  String Function(String day) onDay,
  String date,
  String what,
  String sold,
  String paid,
  String balance,
  String Function(String films) sale,
  String payment,
  String Function(String sum) owes,
  String settled,
  String signs,
});

/// One line of a statement: a sale (what he took) or a payment.
typedef FilmStatementLine = ({
  String date,
  String what,
  double sold,
  double paid,
  double balance,
});

/// A customer's statement (owner, 13.11.2026: «акт сверки»): every sale and
/// every payment in order, the balance after each — what he owes at the end.
List<FilmStatementLine> filmStatement(List<FilmSale> sales) {
  final events = <({String date, String what, double sold, double paid})>[
    for (final s in sales) ...[
      (
        date: s.date,
        what: s.lines
            .map((l) => '${l.title} ${l.metres.toStringAsFixed(1)}')
            .join(', '),
        sold: s.amount ?? 0,
        paid: 0,
      ),
      for (final p in s.payments)
        (
          date: p.date.isEmpty ? s.date : p.date,
          what: '',
          sold: 0,
          paid: p.amount,
        ),
    ],
  ]..sort((a, b) => a.date.compareTo(b.date));
  var balance = 0.0;
  return [
    for (final e in events)
      (
        date: e.date,
        what: e.what,
        sold: e.sold,
        paid: e.paid,
        balance: balance += e.sold - e.paid,
      ),
  ];
}

/// The statement on paper: black on white, A4.
Future<Uint8List> buildFilmStatementPdf(
  String customer,
  List<FilmSale> sales,
  FilmStatementWords words, {
  required String today,
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
  final lines = filmStatement(sales);
  final owes = lines.isEmpty ? 0.0 : lines.last.balance;
  const small = pw.TextStyle(fontSize: 9);
  pw.Widget cell(String text, {bool right = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(
      text,
      style: small,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
  final doc =
      pw.Document(
        theme: pw.ThemeData.withFont(base: font, bold: font),
      )..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(words.title, style: const pw.TextStyle(fontSize: 16)),
            pw.Text(words.customer(customer)),
            pw.Text(words.onDay(mdfDay(today)), style: small),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(60),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(70),
                3: pw.FixedColumnWidth(70),
                4: pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  children: [
                    cell(words.date),
                    cell(words.what),
                    cell(words.sold, right: true),
                    cell(words.paid, right: true),
                    cell(words.balance, right: true),
                  ],
                ),
                for (final l in lines)
                  pw.TableRow(
                    children: [
                      cell(mdfDay(l.date)),
                      cell(l.sold > 0 ? words.sale(l.what) : words.payment),
                      cell(l.sold > 0 ? money.format(l.sold) : '', right: true),
                      cell(l.paid > 0 ? money.format(l.paid) : '', right: true),
                      cell(money.format(l.balance), right: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              owes > 0.5 ? words.owes(money.format(owes)) : words.settled,
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 24),
            pw.Text(words.signs, style: small),
          ],
        ),
      );
  return doc.save();
}
