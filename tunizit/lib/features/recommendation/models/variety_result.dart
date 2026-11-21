const kDefaultWarning =
    'Recommandation indicative. Consultez un technicien agricole avant plantation.';
const kNoMatchMessage =
    'Conditions très contraignantes : consultez un technicien agricole.';

class VarietyResult {
  final String id;
  final String nom;
  final int score;
  final String? photoUrl;
  final List<String> raisons;
  final List<String> limites;
  final bool verified;

  VarietyResult.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        nom = j['variete'] as String,
        score = (j['score'] as num).toInt(),
        photoUrl = j['photo_url'] as String?,
        raisons = List<String>.from(j['raisons'] ?? []),
        limites = List<String>.from(j['limites'] ?? []),
        verified = j['verified'] == true;
}

class RecommendationResponse {
  RecommendationResponse({
    this.requestId,
    required this.resultats,
    this.valeursParDefaut = const [],
    this.message,
    this.avertissement = kDefaultWarning,
    this.input,
  });

  final String? requestId;
  final List<VarietyResult> resultats;
  final List<String> valeursParDefaut;
  final String? message;
  final String avertissement;
  final Map<String, dynamic>? input;

  factory RecommendationResponse.fromJson(
    Map<String, dynamic> j, {
    Map<String, dynamic>? input,
  }) {
    return RecommendationResponse(
      requestId: j['request_id'] as String?,
      resultats: (j['resultats'] as List? ?? [])
          .map((e) => VarietyResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      valeursParDefaut: List<String>.from(j['valeurs_par_defaut'] ?? []),
      message: j['message'] as String?,
      avertissement: (j['avertissement'] as String?) ?? kDefaultWarning,
      input: input,
    );
  }
}

// Une ligne de l'historique (table recommendation_requests).
class HistoryItem {
  final String id;
  final DateTime? createdAt;
  final Map<String, dynamic> input;
  final List<VarietyResult> results;

  HistoryItem.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        createdAt = DateTime.tryParse((j['created_at'] as String?) ?? ''),
        input = Map<String, dynamic>.from((j['input'] as Map?) ?? {}),
        results = ((j['results'] as List?) ?? [])
            .map((e) => VarietyResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

  RecommendationResponse toResponse() => RecommendationResponse(
        requestId: id,
        resultats: results,
        message: results.isEmpty ? kNoMatchMessage : null,
        input: input,
      );
}

class Explanation {
  final String texte;
  final String source; // 'ia' ou 'modele'

  Explanation.fromJson(Map<String, dynamic> j)
      : texte = (j['texte'] as String?) ?? '',
        source = (j['source'] as String?) ?? 'modele';

  bool get isAi => source == 'ia';
}