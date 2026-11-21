// lib/planner/planner_pdf.dart
// Rapport PDF du Smart Orchard Planner : détails de la plantation + plan 2D.
// Le plan est dessiné avec le même PlanPainter que l'écran (rendu identique).
// Fonctionne sur web (téléchargement), Android et iOS (partage / enregistrement).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'planner_calculator.dart';
import 'planner_painter.dart';

final _forest = PdfColor.fromInt(0xFF0E4429);
final _leaf = PdfColor.fromInt(0xFF2E7D4F);
final _tile = PdfColor.fromInt(0xFFEFF8EC);
final _border = PdfColor.fromInt(0xFFD7EBD3);
final _ink = PdfColor.fromInt(0xFF14261B);
final _muted = PdfColor.fromInt(0xFF5E7466);

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _systemLabel(PlantingSystem s) => switch (s) {
  PlantingSystem.pluvial => 'Plantation pluviale',
  PlantingSystem.irrigueClassique => 'Plantation irriguée classique',
  PlantingSystem.superIntensif => 'Plantation super-intensive',
};

/// Dessine le plan 2D hors écran et le renvoie en PNG.
Future<({Uint8List bytes, double aspect})> _renderPlan(
  PlannerResult r,
  double margin,
) async {
  const pixelRatio = 3.0;
  const w = 700.0;
  final h = (w * (r.widthM / r.lengthM) + 40).clamp(240.0, 700.0).toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
  PlanPainter(r, margin).paint(canvas, Size(w, h));

  final image = await recorder.endRecording().toImage(
    (w * pixelRatio).round(),
    (h * pixelRatio).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return (bytes: data!.buffer.asUint8List(), aspect: w / h);
}

pw.Widget _kv(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 4,
        child: pw.Text(k, style: pw.TextStyle(fontSize: 10, color: _muted)),
      ),
      pw.Expanded(
        flex: 6,
        child: pw.Text(
          v,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _card(String title, List<pw.Widget> children) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(14),
  decoration: pw.BoxDecoration(
    borderRadius: pw.BorderRadius.circular(10),
    border: pw.Border.all(color: _border),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _forest,
        ),
      ),
      pw.SizedBox(height: 8),
      ...children,
    ],
  ),
);

pw.Widget _legend(PlannerResult r) {
  final varieties = r.varietyRows.keys.toList();
  return pw.Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final e in r.varietyRows.entries)
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(
                  plannerColorForVariety(e.key, varieties).toARGB32(),
                ),
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              '${e.key} : ${e.value} rangée(s)',
              style: pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ],
        ),
    ],
  );
}

/// Génère le PDF puis le télécharge (web) ou ouvre le partage (mobile).
Future<void> sharePlannerPdf(
  PlannerResult r,
  double margin, {
  String? governorate,
  bool irrigated = false,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final plan = await _renderPlan(r, margin);

  final doc = pw.Document(
    title: 'Plan de plantation Tunizit',
    author: 'Tunizit',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  final estimated = r.dimensionsEstimated ? ' (estimées, rectangle 2:1)' : '';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber}/${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ),
      build: (ctx) => [
        // En-tête
        pw.Row(
          children: [
            pw.Container(
              width: 34,
              height: 34,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _leaf,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'T',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TUNIZIT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: pw.FontWeight.bold,
                    color: _muted,
                  ),
                ),
                pw.Text(
                  'Rapport de plantation · Smart Orchard Planner',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _forest,
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Text(_today(), style: pw.TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
        pw.SizedBox(height: 18),

        // Synthèse
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _tile,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${r.totalTrees} arbres',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: _forest,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _systemLabel(r.system),
                style: pw.TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Terrain
        _card('Terrain', [
          if (governorate != null) _kv('Gouvernorat', governorate),
          _kv('Zone', _cap(r.zone.name)),
          _kv('Irrigation', irrigated ? 'Oui' : 'Non (pluvial)'),
          _kv(
            'Dimensions',
            '${_fmt(r.lengthM)} × ${_fmt(r.widthM)} m$estimated',
          ),
          _kv('Surface', '${(r.surfaceM2 / 10000).toStringAsFixed(2)} ha'),
          _kv(
            'Surface utile',
            '${(r.usableAreaM2 / 10000).toStringAsFixed(2)} ha',
          ),
          _kv('Marge de bordure', '${_fmt(margin)} m'),
        ]),
        pw.SizedBox(height: 12),

        // Plantation
        _card('Détails de la plantation', [
          _kv('Rangées', '${r.rows} × ${r.treesPerRow} arbres'),
          _kv(
            'Espacement',
            '${_fmt(r.rowSpacingM)} m entre rangées · '
                '${_fmt(r.treeSpacingM)} m sur la rangée',
          ),
          _kv('Densité', '${r.densityPerHa.toStringAsFixed(0)} arbres/ha'),
          _kv('Total', '${r.totalTrees} arbres'),
        ]),
        pw.SizedBox(height: 12),

        // Plan 2D
        _card('Schéma de plantation (vue de dessus)', [
          pw.Center(
            child: pw.SizedBox(
              width: 500,
              height: 500 / plan.aspect,
              child: pw.Image(pw.MemoryImage(plan.bytes), fit: pw.BoxFit.fill),
            ),
          ),
          if (r.varietyRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _legend(r),
          ],
        ]),

        // Remarques
        if (r.warnings.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _card('Remarques', [
            for (final w in r.warnings)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '• $w',
                  style: pw.TextStyle(fontSize: 9.5, color: _muted),
                ),
              ),
          ]),
        ],

        pw.SizedBox(height: 14),
        pw.Text(
          'Document indicatif : la répartition proposée est une organisation '
          'de plantation, pas une prescription agronomique. Elle ne remplace '
          'pas l\u2019avis d\u2019un ingénieur agronome sur le terrain.',
          style: pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'plan_plantation_tunizit.pdf',
  );
}
