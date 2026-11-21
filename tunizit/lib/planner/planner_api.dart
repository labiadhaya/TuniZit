// lib/planner/planner_api.dart
// Appel du backend : POST /api/planner/generate
// pubspec.yaml : ajouter  http: ^1.2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'planner_calculator.dart';

class PlannerApi {
  //web: http://localhost:5000
  // Émulateur Android : http://10.0.2.2:3000
  // Téléphone réel : http://IP_DE_TON_PC:3000 (même Wi-Fi)
  static const String baseUrl = 'http://localhost:5000';

  static Future<PlannerResult> generate(PlannerInput input) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/planner/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(input.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> body;
      try {
        body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw const PlannerException('Réponse du serveur invalide.');
      }

      if (response.statusCode == 200 && body['success'] == true) {
        return PlannerResult.fromJson(body['data'] as Map<String, dynamic>);
      }

      throw PlannerException(
        (body['message'] as String?) ?? 'Erreur lors de la génération du plan.',
      );
    } on TimeoutException {
      throw const PlannerException(
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on SocketException {
      throw const PlannerException(
        'Impossible de contacter le serveur. Vérifiez votre connexion.',
      );
    }
  }
}
