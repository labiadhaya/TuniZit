import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config.dart';
import '../models/variety_result.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class RecommendationService {
  Future<RecommendationResponse> getRecommendations(
      Map<String, dynamic> form) async {
    final body = await _call('POST', '/api/recommendations/varieties',
        payload: form);
    return RecommendationResponse.fromJson(body, input: form);
  }

  Future<Explanation> explain(String requestId, String langue) async {
    final body = await _call(
      'POST',
      '/api/recommendations/explain',
      payload: {'request_id': requestId, 'langue': langue},
      timeout: const Duration(seconds: 35),
    );
    return Explanation.fromJson(body);
  }

  Future<List<HistoryItem>> getHistory() async {
    final body = await _call('GET', '/api/recommendations/history');
    final list = (body['historique'] as List?) ?? [];
    return list
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw ApiException('Vous devez vous connecter.');

    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final http.Response res;
    try {
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(timeout);
      } else {
        res = await http
            .post(uri, headers: headers, body: jsonEncode(payload ?? {}))
            .timeout(timeout);
      }
    } on TimeoutException {
      throw ApiException('Le serveur met trop de temps à répondre.');
    } catch (_) {
      throw ApiException(
          'Impossible de joindre le serveur. Vérifiez la connexion.');
    }

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode == 200) return body;
    if (res.statusCode == 401) {
      throw ApiException('Session expirée. Reconnectez-vous.');
    }
    if (res.statusCode == 404) throw ApiException('Recommandation introuvable.');
    if (res.statusCode == 429) {
      throw ApiException('Trop de demandes. Réessayez dans une minute.');
    }
    if (res.statusCode == 400 && body['errors'] is List) {
      throw ApiException((body['errors'] as List).join(' ; '));
    }
    throw ApiException('Erreur serveur (${res.statusCode}).');
  }
}