import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// What a sheet map's QR says: «SAW:Р-0042:1» — scanned, it opens the job
/// at that sheet to be marked sawn.
String sawSheetQr(String job, int sheet) => 'SAW:$job:$sheet';

/// A cut in the sawyer's words: what, against which fence, how much.
String sawCutText(AppLocalizations l10n, SawCut cut, NumberFormat mm) {
  final set = mm.format(cut.set);
  final parts = cut.parts.map((p) => '${p.n}').toSet().join(', ');
  final what = switch (cut.kind) {
    SawCutKind.trim => l10n.sawCutTrim(set),
    SawCutKind.strip => l10n.sawCutStrip(set),
    SawCutKind.cross => l10n.sawCutCross(set),
    SawCutKind.split => l10n.sawCutSplit(set),
    SawCutKind.trimPart => l10n.sawCutTrimPart(set),
  };
  return parts.isEmpty ? what : '$what · ${l10n.sawCutParts(parts)}';
}

/// Whether the cut at [at] keeps the fence where the last cut of its kind
/// left it — «упор тот же»: no measuring.
bool sawSameFence(List<SawCut> cuts, int at) {
  final cut = cuts[at];
  for (var j = at - 1; j >= 0; j--) {
    final c = cuts[j];
    if (c.kind != SawCutKind.trim && c.along == cut.along) {
      return c.set == cut.set;
    }
  }
  return false;
}

/// A part's bands in words: «низ 2, бока 0,4»; empty — none.
String sawEdgesText(
  AppLocalizations l10n,
  List<double> edges,
  NumberFormat mm,
) {
  final names = [
    l10n.sawEdgeTop,
    l10n.sawEdgeBottom,
    l10n.sawEdgeLeft,
    l10n.sawEdgeRight,
  ];
  return [
    for (final (i, e) in edges.take(4).indexed)
      if (e > 0) '${names[i]} ${mm.format(e)}',
  ].join(', ');
}

Future<pw.ThemeData> _theme() async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
  );
  return pw.ThemeData.withFont(base: font, bold: font);
}

/// The paper map (owner, 28.11.2026), a page a sheet, A4 standing: the job,
/// the sheet and its QR; the sheet as it lies on the carriage, the fence on
/// its side; the cuts in order with a box to tick; «Пилил», «Дата», «Брак»
/// to write in; the offcut that goes to the shelf. Black and grey only.
Future<Uint8List> buildSawMapPdf(
  CuttingJob job,
  AppLocalizations l10n, {
  String locale = 'ru',
  int? onlySheet,
}) async {
  final mm = NumberFormat('0.#', locale);
  final doc = pw.Document(theme: await _theme());
  final sheets = job.plan.sheets;
  for (final (i, sheet) in sheets.indexed) {
    final no = i + 1;
    if (onlySheet != null && no != onlySheet) continue;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${job.name} · ${l10n.sawSheetOf(no, sheets.length)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${job.material} · '
                        '${mm.format(job.saw.sheetHeightMm)} × '
                        '${mm.format(job.saw.sheetWidthMm)}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      if (job.title.isNotEmpty)
                        pw.Text(
                          job.title,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      pw.Text(
                        l10n.sawPrintSaw(
                          mm.format(job.saw.kerfMm),
                          mm.format(job.saw.trimMm),
                        ),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 64,
                  height: 64,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: sawSheetQr(job.name, no),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sheetDrawing(job, sheet, mm, maxW: 300, maxH: 540),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _cutList(l10n, sheet, mm)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.grey300,
              child: pw.Text(
                l10n.sawPrintMeasure,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '${l10n.sawPrintSawnBy} ____________________    '
              '${l10n.sawPrintDate} ____________',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${l10n.sawPrintDefects} ____________________________',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 8),
            for (final o in sheet.offcuts)
              pw.Text(
                l10n.sawOffcutToShelf(
                  '${mm.format(math.max(o.width, o.height))} × '
                  '${mm.format(math.min(o.width, o.height))}',
                ),
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.Text(
              l10n.sawPrintEdgeLegend,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _cutList(AppLocalizations l10n, SawPlanSheet sheet, NumberFormat mm) {
  bool same(SawCut cut, int at) =>
      cut.kind != SawCutKind.trim && sawSameFence(sheet.cuts, at);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        l10n.sawPrintCuts,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      for (final (i, cut) in sheet.cuts.indexed)
        _cutRow(l10n, i, cut, mm, same: same(cut, i)),
    ],
  );
}

pw.Widget _cutRow(
  AppLocalizations l10n,
  int i,
  SawCut cut,
  NumberFormat mm, {
  required bool same,
}) {
  final tail = same ? ' · ${l10n.sawSameFence}' : '';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 9,
          height: 9,
          margin: const pw.EdgeInsets.only(top: 1, right: 4),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
        ),
        pw.Expanded(
          child: pw.Text(
            '${i + 1}. ${sawCutText(l10n, cut, mm)}$tail',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: cut.kind == SawCutKind.strip
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The sheet to scale, standing as the settings write it, mirrored when the
/// fence is on the right — the same picture as the screen's.
pw.Widget _sheetDrawing(
  CuttingJob job,
  SawPlanSheet sheet,
  NumberFormat mm, {
  required double maxW,
  required double maxH,
}) {
  final h = job.saw.sheetHeightMm;
  final w = job.saw.sheetWidthMm;
  final trim = job.saw.trimMm;
  final usedW = w - 2 * trim;
  final scale = h > 0 && w > 0 ? math.min(maxW / w, maxH / h) : 0.0;
  final size = PdfPoint(w * scale + 14, h * scale);
  return pw.SizedBox(
    width: size.x,
    height: size.y + 14,
    child: pw.CustomPaint(
      size: PdfPoint(size.x, size.y + 14),
      painter: (canvas, box) {
        final left = job.saw.fence == FenceSide.left ? 10.0 : 0.0;
        final top = box.y;
        // pdf's y runs up; the sheet's runs down from the top.
        PdfRect rect(double x, double y, double rw, double rh) {
          final across = job.saw.fence == FenceSide.left ? x : usedW - x - rw;
          return PdfRect(
            left + (trim + across) * scale,
            top - (trim + y + rh) * scale,
            rw * scale,
            rh * scale,
          );
        }

        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(0.6)
          ..setLineDashPattern([3, 2])
          ..drawRect(left, top - h * scale, w * scale, h * scale)
          ..strokePath()
          ..setLineDashPattern();
        for (final r in sheet.waste) {
          final b = rect(r.x, r.y, r.width, r.height);
          canvas
            ..setFillColor(PdfColors.grey400)
            ..drawRect(b.x, b.y, b.width, b.height)
            ..fillPath();
        }
        for (final r in sheet.offcuts) {
          final b = rect(r.x, r.y, r.width, r.height);
          canvas
            ..setFillColor(PdfColors.grey200)
            ..drawRect(b.x, b.y, b.width, b.height)
            ..fillPath()
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(0.6)
            ..drawRect(b.x, b.y, b.width, b.height)
            ..strokePath();
        }
        for (final p in sheet.parts) {
          final b = rect(p.x, p.y, p.width, p.height);
          canvas
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(0.8)
            ..drawRect(b.x, b.y, b.width, b.height)
            ..strokePath();
          // Bands: thick for 1 mm and more, thin dashed below.
          final sides = [
            (b.x, b.y + b.height, b.x + b.width, b.y + b.height),
            (b.x, b.y, b.x + b.width, b.y),
            (b.x, b.y, b.x, b.y + b.height),
            (b.x + b.width, b.y, b.x + b.width, b.y + b.height),
          ];
          for (final (i, (x1, y1, x2, y2)) in sides.indexed) {
            final e = i < p.edges.length ? p.edges[i] : 0;
            if (e <= 0) continue;
            canvas
              ..setLineWidth(e >= 1 ? 2.4 : 0.8)
              ..setLineDashPattern(e >= 1 ? const [] : const [2, 1.5])
              ..moveTo(x1, y1)
              ..lineTo(x2, y2)
              ..strokePath()
              ..setLineDashPattern();
          }
        }
        // The fence beside the sheet.
        final fenceX = job.saw.fence == FenceSide.left ? 3.0 : w * scale + 6;
        canvas
          ..setFillColor(PdfColors.grey700)
          ..drawRect(fenceX, top - h * scale, 4, h * scale)
          ..fillPath();
      },
      child: pw.Stack(
        children: [
          for (final p in sheet.parts)
            if (p.width * scale > 12 && p.height * scale > 10)
              pw.Positioned(
                left:
                    (job.saw.fence == FenceSide.left ? 10.0 : 0.0) +
                    (trim +
                            (job.saw.fence == FenceSide.left
                                ? p.x
                                : usedW - p.x - p.width)) *
                        scale,
                top: (trim + p.y) * scale,
                child: pw.SizedBox(
                  width: p.width * scale,
                  height: p.height * scale,
                  child: pw.Center(
                    child: pw.Text(
                      '${p.n}',
                      style: pw.TextStyle(
                        fontSize: math.min(14, p.height * scale / 2),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.Center(
              child: pw.Text(
                mm.format(w),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The labels (owner, 28.11.2026), 58 × 40 mm, one a part: the order and
/// its customer, the part's number and name, its size as entered, the
/// board, its bands in words and drawn, and the sheet's QR.
Future<Uint8List> buildSawLabelsPdf(
  CuttingJob job,
  AppLocalizations l10n, {
  String locale = 'ru',
}) async {
  final mm = NumberFormat('0.#', locale);
  final doc = pw.Document(theme: await _theme());
  const format = PdfPageFormat(
    58 * PdfPageFormat.mm,
    40 * PdfPageFormat.mm,
    marginAll: 2 * PdfPageFormat.mm,
  );
  final customers = {for (final o in job.orders) o.order: o};
  for (final (i, sheet) in job.plan.sheets.indexed) {
    final pieces = [...sheet.parts]
      ..sort((a, b) => a.n != b.n ? a.n.compareTo(b.n) : a.k.compareTo(b.k));
    for (final p in pieces) {
      final part = job.part(p.n);
      final order = part?.order == null ? null : customers[part!.order];
      final head = order != null
          ? '${order.number} ${order.customer}'
          : (job.orders.length == 1
                ? '${job.orders.first.number} ${job.orders.first.customer}'
                : job.name);
      final name = (part?.name ?? '').isEmpty
          ? l10n.sawPartDefault(p.n)
          : '${l10n.sawPartDefault(p.n)} · ${part!.name}';
      final edges = part == null ? '' : sawEdgesText(l10n, part.edges, mm);
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      head,
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      name,
                      maxLines: 2,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      part == null
                          ? '${mm.format(p.height)} × ${mm.format(p.width)}'
                          : '${mm.format(part.height)} × ${mm.format(part.width)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      job.material,
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      edges.isEmpty
                          ? l10n.sawEdgeNone
                          : '${l10n.sawColEdge}: $edges',
                      maxLines: 2,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      '${job.name} · ${l10n.sawSheetOf(i + 1, job.plan.sheets.length)}',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              ),
              pw.Column(
                children: [
                  pw.SizedBox(
                    width: 14 * PdfPageFormat.mm,
                    height: 14 * PdfPageFormat.mm,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: sawSheetQr(job.name, i + 1),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (part != null) _edgeSketch(part.edges),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
  return doc.save();
}

/// A small rectangle with its banded sides drawn thick.
pw.Widget _edgeSketch(List<double> edges) {
  pw.BorderSide side(int i) {
    final e = i < edges.length ? edges[i] : 0;
    return pw.BorderSide(width: e >= 1 ? 2.4 : (e > 0 ? 1.2 : 0.4));
  }

  return pw.Container(
    width: 30,
    height: 20,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: side(0),
        bottom: side(1),
        left: side(2),
        right: side(3),
      ),
    ),
  );
}

/// An offcut's label: it goes on the piece, and its QR finds it on the shelf.
Future<Uint8List> buildSawOffcutLabelsPdf(
  CuttingJob job,
  AppLocalizations l10n, {
  String locale = 'ru',
}) async {
  final mm = NumberFormat('0.#', locale);
  final doc = pw.Document(theme: await _theme());
  const format = PdfPageFormat(
    58 * PdfPageFormat.mm,
    40 * PdfPageFormat.mm,
    marginAll: 2 * PdfPageFormat.mm,
  );
  for (final sheet in job.sheets) {
    for (final o in sheet.offcuts) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.sawOffcutLabel,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(o.name, style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      '${mm.format(o.lengthMm)} × ${mm.format(o.widthMm)}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      job.material,
                      maxLines: 2,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      '${job.name} · ${l10n.sawSheetOf(sheet.sheetNo, job.sheets.length)}',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(
                width: 18 * PdfPageFormat.mm,
                height: 18 * PdfPageFormat.mm,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: o.qr,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  return doc.save();
}

Future<void> printSawPdf(String name, Future<Uint8List> Function() build) =>
    Printing.layoutPdf(name: name, onLayout: (_) => build());
