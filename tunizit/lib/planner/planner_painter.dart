// lib/planner/plan_painter.dart
// Dessine la parcelle vue de dessus : bordure, zone utile, rangées numérotées, arbres.
// Longueur = axe horizontal, largeur = axe vertical. Les rangées sont parallèles à la longueur.
// lib/planner/plan_painter.dart
// Dessin 2D de la parcelle avec une couleur par bloc de variété.

import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'planner_calculator.dart';
import '../theme/app_theme.dart';

const List<Color> plannerVarietyPalette = [
  Color(0xFF2E6B45),
  Color(0xFFB7793E),
  Color(0xFF547A9E),
  Color(0xFF9872A8),
  Color(0xFFB45D5D),
  Color(0xFF7D8660),
  Color(0xFF4F9290),
  Color(0xFF9A8055),
];

Color plannerColorForVariety(String variety, List<String> varieties) {
  final index = varieties.indexOf(variety);
  if (index < 0) return const Color(0xFF2E5D34);
  return plannerVarietyPalette[index % plannerVarietyPalette.length];
}

class PlanPainter extends CustomPainter {
  PlanPainter(this.r, this.margin);

  final PlannerResult r;
  final double margin;

  void _drawTree(
    Canvas canvas,
    Offset p,
    double radius,
    Color color, {
    required bool detailed,
  }) {
    if (!detailed) {
      canvas.drawCircle(p, radius, Paint()..color = color);
      return;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: p.translate(radius * 0.3, radius * 0.8),
        width: radius * 2.2,
        height: radius * 0.8,
      ),
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: p.translate(0, radius * 0.9),
        width: radius * 0.35,
        height: radius * 0.7,
      ),
      Paint()..color = const Color(0xFF6B4F2A),
    );

    final light = Color.lerp(color, Colors.white, 0.4)!;
    canvas.drawCircle(
      p,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [light, color],
        ).createShader(Rect.fromCircle(center: p, radius: radius)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const labelSpace = 26.0;
    const pad = 8.0;

    final availW = size.width - labelSpace - pad;
    final availH = size.height - 2 * pad;
    final sx = availW / r.lengthM;
    final sy = availH / r.widthM;
    final scale = sx < sy ? sx : sy;

    final pw = r.lengthM * scale;
    final ph = r.widthM * scale;
    final ox = labelSpace + (availW - pw) / 2;
    final oy = pad + (availH - ph) / 2;

    final parcel = Rect.fromLTWH(ox, oy, pw, ph);
    canvas.drawRect(parcel, Paint()..color = AppColors.tile);
    canvas.drawRect(
      parcel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8B6B3E),
    );

    final usable = Rect.fromLTWH(
      ox + margin * scale,
      oy + margin * scale,
      pw - 2 * margin * scale,
      ph - 2 * margin * scale,
    );
    canvas.drawRect(
      usable,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x552E5D34),
    );

    final minSpacing = r.rowSpacingM < r.treeSpacingM
        ? r.rowSpacingM
        : r.treeSpacingM;
    final radius = (minSpacing * scale * 0.3).clamp(1.2, 7.0).toDouble();

    final varieties = r.varietyRows.keys.toList();
    final groupedPoints = <Color, List<Offset>>{};

    for (var row = 0; row < r.rows; row++) {
      final y = oy + (margin + row * r.rowSpacingM) * scale;
      final variety = row < r.rowVarieties.length ? r.rowVarieties[row] : '';
      final color = variety.isEmpty
          ? const Color(0xFF2E5D34)
          : plannerColorForVariety(variety, varieties);

      final points = groupedPoints.putIfAbsent(color, () => <Offset>[]);
      for (var tree = 0; tree < r.treesPerRow; tree++) {
        final x = ox + (margin + tree * r.treeSpacingM) * scale;
        points.add(Offset(x, y));
      }
    }

    for (final entry in groupedPoints.entries) {
      final paint = Paint()..color = entry.key;
      if (entry.value.length > 5000) {
        canvas.drawPoints(
          PointMode.points,
          entry.value,
          paint
            ..strokeWidth = radius * 2
            ..strokeCap = StrokeCap.round,
        );
      } else {
        for (final point in entry.value) {
          _drawTree(
            canvas,
            point,
            radius,
            entry.key,
            detailed: entry.value.length <= 800 && radius >= 3,
          );
        }
      }
    }

    if (r.rows <= 25) {
      for (var i = 0; i < r.rows; i++) {
        final y = oy + (margin + i * r.rowSpacingM) * scale;
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(ox - tp.width - 6, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) =>
      oldDelegate.r != r || oldDelegate.margin != margin;
}
