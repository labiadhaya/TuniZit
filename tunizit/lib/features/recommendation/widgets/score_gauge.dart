import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';

class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 60});

  final int score;
  final double size;

  static Color colorFor(int s) {
    if (s >= 80) return AppColors.good;
    if (s >= 60) return AppColors.medium;
    return AppColors.low;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(score);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: size * 0.27,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}