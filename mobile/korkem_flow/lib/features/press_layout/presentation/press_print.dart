import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Words on the printed map, in the reader's language.
typedef PressPrintWords = ({
  String textured,
  String plain,
  String Function(String metres) total,
  String Function(int count) sheet,
  String Function(int count) copies,
  String Function(String size) size,
  String Function(String metres) section,
  String Function(String area) area,
  String Function(String area, String share) parts,
  String Function(String area, String share) waste,
  String Function(int count) count,
  String Function(String metres) perimeter,
  String Function(String gap, String margin) gap,
  String details,
  String Function(String positions) tooBig,
  String Function(int count) page,
});

/// Loads that are the same placement, printed once with a copy count — as
/// cutting2 does: «Кол-во копий: 2».
List<({PressLoad load, int copies})> groupLoads(List<PressLoad> loads) {
  final groups = <String, ({PressLoad load, int copies})>{};
  for (final load in loads) {
    final key = [
      load.lengthMm,
      for (final p in load.placed)
        '${p.pos}:${p.x}:${p.y}:${p.width}:${p.height}',
    ].join('|');
    final seen = groups[key];
    groups[key] = (load: load, copies: (seen?.copies ?? 0) + 1);
  }
  return groups.values.toList();
}

/// The press map on paper, two loads to a portrait A4 page, as the shop's
/// cutting2 prints it: per load a table — sheet number, copies, size, film
/// section, areas, waste, parts, perimeter, gap — then the map to scale with
/// each facade's line number and, beside it, the list of parts.
///
/// The order, customer and film head every page in large type; a textured
/// film adds «НЕ ВРАЩАТЬ» on a black band, its parts hatched grey with an
/// arrow. Black and grey only, for a monochrome shop printer.
Future<Uint8List> buildPressPdf(
  List<FilmLayout> films,
  PressSettings press,
  PressPrintWords words, {
  String locale = 'ru',
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final number = NumberFormat('0.##', locale);
  var page = 0;
  for (final film in films) {
    final groups = groupLoads(film.loads);
    for (var first = 0; first < groups.length; first += 2) {
      page += 1;
      final onPage = groups.sublist(first, math.min(first + 2, groups.length));
      final pageNumber = page;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  words.page(pageNumber),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Text(film.title, style: const pw.TextStyle(fontSize: 17)),
              pw.SizedBox(height: 4),
              _kind(film, words),
              pw.SizedBox(height: 4),
              pw.Text(
                words.total(number.format(film.filmM)),
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (film.tooBig.isNotEmpty && first == 0)
                pw.Text(
                  words.tooBig(film.tooBig.toSet().join(', ')),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              for (final (i, group) in onPage.indexed)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: _block(
                      group.load,
                      group.copies,
                      first + i + 1,
                      press,
                      film.textured,
                      words,
                      number,
                    ),
                  ),
                ),
              if (onPage.length == 1) pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ),
      );
    }
  }
  return doc.save();
}

pw.Widget _kind(FilmLayout film, PressPrintWords words) => film.textured
    ? pw.Container(
        color: PdfColors.black,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: pw.Text(
          words.textured,
          style: const pw.TextStyle(fontSize: 16, color: PdfColors.white),
        ),
      )
    : pw.Text(words.plain, style: const pw.TextStyle(fontSize: 10));

pw.Widget _block(
  PressLoad load,
  int copies,
  int sheet,
  PressSettings press,
  bool textured,
  PressPrintWords words,
  NumberFormat number,
) {
  final sheetArea = load.lengthMm * press.widthMm / 1e6;
  final partsArea = load.placed.fold<double>(
    0,
    (sum, p) => sum + p.width * p.height / 1e6,
  );
  final waste = sheetArea - math.min(partsArea, sheetArea);
  final perimeter = load.placed.fold<double>(
    0,
    (sum, p) => sum + 2 * (p.width + p.height) / 1000,
  );
  String share(double part) =>
      sheetArea > 0 ? (part / sheetArea * 100).toStringAsFixed(1) : '0';
  final counts = <int, ({String size, int count})>{};
  for (final p in load.placed) {
    final w = (p.rotated ? p.height : p.width).round();
    final h = (p.rotated ? p.width : p.height).round();
    final seen = counts[p.pos];
    counts[p.pos] = (size: '$w×$h', count: (seen?.count ?? 0) + 1);
  }
  const small = pw.TextStyle(fontSize: 8);
  pw.Widget cell(List<String> lines) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [for (final l in lines) pw.Text(l, style: small)],
    ),
  );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(width: 0.6),
        children: [
          pw.TableRow(
            children: [
              cell([
                words.sheet(sheet),
                words.copies(copies),
                words.size(
                  '${load.lengthMm.round()}×${press.widthMm.round()}',
                ),
                words.section(number.format(load.filmM)),
              ]),
              cell([
                words.area(sheetArea.toStringAsFixed(2)),
                words.parts(partsArea.toStringAsFixed(2), share(partsArea)),
                words.waste(waste.toStringAsFixed(2), share(waste)),
              ]),
              cell([
                words.count(load.placed.length),
                words.perimeter(perimeter.toStringAsFixed(2)),
                words.gap(
                  press.gapMm.round().toString(),
                  press.marginMm.round().toString(),
                ),
              ]),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Expanded(
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.LayoutBuilder(
                builder: (context, constraints) => _map(
                  load,
                  press.widthMm,
                  textured: textured,
                  maxWidth: constraints?.maxWidth ?? 0,
                  maxHeight: constraints?.maxHeight ?? 0,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 92,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    words.details,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  for (final entry in counts.entries)
                    pw.Text(
                      '№ ${entry.key}  ${entry.value.size} - '
                      '${entry.value.count}',
                      style: small,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The table to scale, each part outlined with its line number; textured
/// parts hatched grey with an arrow the way the pattern runs.
pw.Widget _map(
  PressLoad load,
  double widthMm, {
  required bool textured,
  required double maxWidth,
  required double maxHeight,
}) {
  if (load.lengthMm <= 0 || widthMm <= 0 || maxWidth <= 0 || maxHeight <= 0) {
    return pw.SizedBox();
  }
  final scale = math.min(maxWidth / load.lengthMm, maxHeight / widthMm);
  final width = load.lengthMm * scale;
  final height = widthMm * scale;
  return pw.SizedBox(
    width: width,
    height: height,
    child: pw.Stack(
      children: [
        pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(width: 1.2),
          ),
        ),
        for (final p in load.placed)
          pw.Positioned(
            left: p.x * scale,
            top: p.y * scale,
            child: _part(p, scale, textured: textured),
          ),
      ],
    ),
  );
}

pw.Widget _part(PlacedPart p, double scale, {required bool textured}) {
  final w = p.width * scale;
  final h = p.height * scale;
  final side = math.min(w, h);
  return pw.Container(
    width: w,
    height: h,
    decoration: pw.BoxDecoration(
      color: textured ? PdfColors.grey400 : PdfColors.white,
      border: pw.Border.all(width: textured ? 1.6 : 0.8),
    ),
    child: pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Text(
          '${p.pos}',
          style: pw.TextStyle(fontSize: (side * 0.45).clamp(6, 32)),
        ),
        if (side > 18) ...[
          pw.Positioned(
            right: 2,
            top: 1,
            child: pw.Text(
              '${(p.rotated ? p.height : p.width).round()}',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
          pw.Positioned(
            left: 2,
            bottom: 1,
            child: pw.Text(
              '${(p.rotated ? p.width : p.height).round()}',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
        ],
        if (textured)
          pw.Positioned(
            left: 3,
            top: 2,
            child: pw.Text(
              '↑',
              style: pw.TextStyle(fontSize: (side * 0.3).clamp(6, 20)),
            ),
          ),
      ],
    ),
  );
}

/// Hand the PDF to the system's print dialog.
Future<void> printPressLayout({
  required String name,
  required Future<Uint8List> Function() build,
}) => Printing.layoutPdf(name: name, onLayout: (_) => build());
