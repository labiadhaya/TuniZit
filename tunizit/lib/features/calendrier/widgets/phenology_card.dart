import 'package:flutter/material.dart';

import 'calendrier_theme.dart';
import '../models/activity.dart';

/// Carte du haut : CYCLE PHÉNOLOGIQUE • Automne / Pré-récolte & Véraison + conseil.
class PhenologyCard extends StatelessWidget {
  const PhenologyCard({super.key, required this.info});
  final PhenologyInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CalColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: CalColors.phenoIconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: CalColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CYCLE PHÉNOLOGIQUE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: CalColors.phenoLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CalColors.phenoDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        info.saison,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CalColors.phenoSeason,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  info.phase,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: CalColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.conseil,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: CalColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
