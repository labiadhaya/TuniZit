import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// URL de l'API.
/// - Émulateur Android : http://10.0.2.2:3000
/// - Téléphone réel    : flutter run --dart-define=API_URL=http://192.168.1.XX:3000
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
}

class ScanException implements Exception {
  final String message;
  ScanException(this.message);
  @override
  String toString() => message;
}

List<String> _list(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

// ───────────────────────── Identifiant d'appareil ─────────────────────────

/// Identifiant anonyme stocké sur le téléphone (pas de compte pour l'instant).
class DeviceId {
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = _uuidV4();
      await prefs.setString('device_id', id);
    }
    return _cached = id;
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

// ───────────────────────── Modèles ─────────────────────────

class Differential {
  final String nameFr;
  final String? nameAr;
  final double probability;
  Differential({required this.nameFr, this.nameAr, required this.probability});

  factory Differential.fromJson(Map<String, dynamic> j) => Differential(
    nameFr: (j['name_fr'] ?? '').toString(),
    nameAr: j['name_ar']?.toString(),
    probability: _num(j['probability']),
  );
}

class Treatment {
  final List<String> immediateActions;
  final List<String> organic;
  final List<String> chemical;
  final String? timing;
  Treatment({
    this.immediateActions = const [],
    this.organic = const [],
    this.chemical = const [],
    this.timing,
  });

  bool get isEmpty =>
      immediateActions.isEmpty &&
      organic.isEmpty &&
      chemical.isEmpty &&
      (timing == null || timing!.isEmpty);

  factory Treatment.fromJson(Map<String, dynamic>? j) => Treatment(
    immediateActions: _list(j?['immediate_actions']),
    organic: _list(j?['organic']),
    chemical: _list(j?['chemical']),
    timing: j?['timing']?.toString(),
  );
}

class Parcel {
  final String id;
  final String name;
  final String? location;
  final String? variety;
  final int? treesCount;
  Parcel({
    required this.id,
    required this.name,
    this.location,
    this.variety,
    this.treesCount,
  });

  factory Parcel.fromJson(Map<String, dynamic> j) => Parcel(
    id: j['id'].toString(),
    name: (j['name'] ?? '').toString(),
    location: j['location']?.toString(),
    variety: j['variety']?.toString(),
    treesCount: (j['trees_count'] as num?)?.toInt(),
  );

  String get subtitle => [
    if ((location ?? '').isNotEmpty) location!,
    if ((variety ?? '').isNotEmpty) variety!,
    if (treesCount != null) '$treesCount arbres',
  ].join(' • ');
}

class ScanResult {
  final bool isOlivePlant;
  final bool imageUsable;
  final List<String> imageIssues;
  final List<String> retakeTips;
  final String part;
  final String status;
  final String? diseaseFr;
  final String? diseaseAr;
  final String? pathogen;
  final String category;
  final double confidence;
  final List<Differential> differential;
  final List<String> symptoms;
  final String? severity;
  final String urgency;
  final String spreadRisk;
  final List<String> riskFactors;
  final Treatment treatment;
  final List<String> prevention;
  final List<String> followUp;
  final bool needsExpert;
  final String? expertReason;
  final String advice;
  final String? imageUrl;
  final String? scanId; // affichage : TZ-XXXX
  final String? dbId; // identifiant réel en base (uuid)

  ScanResult({
    required this.isOlivePlant,
    required this.imageUsable,
    required this.imageIssues,
    required this.retakeTips,
    required this.part,
    required this.status,
    this.diseaseFr,
    this.diseaseAr,
    this.pathogen,
    required this.category,
    required this.confidence,
    required this.differential,
    required this.symptoms,
    this.severity,
    required this.urgency,
    required this.spreadRisk,
    required this.riskFactors,
    required this.treatment,
    required this.prevention,
    required this.followUp,
    required this.needsExpert,
    this.expertReason,
    required this.advice,
    this.imageUrl,
    this.scanId,
    this.dbId,
  });

  bool get isHealthy => status == 'healthy';
  bool get isUncertain => status == 'uncertain';

  factory ScanResult.fromJson(Map<String, dynamic> j) {
    final q = (j['image_quality'] as Map?)?.cast<String, dynamic>();
    return ScanResult(
      isOlivePlant: j['is_olive_plant'] != false,
      imageUsable: q?['usable'] != false,
      imageIssues: _list(q?['issues']),
      retakeTips: _list(q?['retake_tips']),
      part: (j['part_analyzed'] ?? 'unknown').toString(),
      status: (j['status'] ?? 'uncertain').toString(),
      diseaseFr: j['disease_name_fr']?.toString(),
      diseaseAr: j['disease_name_ar']?.toString(),
      pathogen: j['pathogen_scientific']?.toString(),
      category: (j['category'] ?? 'none').toString(),
      confidence: _num(j['confidence']).clamp(0.0, 1.0),
      differential: ((j['differential'] as List?) ?? [])
          .map((e) => Differential.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      symptoms: _list(j['symptoms_observed']),
      severity: j['severity']?.toString(),
      urgency: (j['urgency'] ?? 'none').toString(),
      spreadRisk: (j['spread_risk'] ?? 'low').toString(),
      riskFactors: _list(j['risk_factors']),
      treatment: Treatment.fromJson(
        (j['treatment'] as Map?)?.cast<String, dynamic>(),
      ),
      prevention: _list(j['prevention']),
      followUp: _list(j['follow_up']),
      needsExpert: j['needs_expert'] == true,
      expertReason: j['expert_reason']?.toString(),
      advice: (j['advice'] ?? '').toString(),
      imageUrl: j['image_url']?.toString(),
      scanId: j['scan_id']?.toString(),
      dbId: j['db_id']?.toString(),
    );
  }
}

// ───────────────────────── Appels API ─────────────────────────

class _Api {
  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  static const _headers = {'Content-Type': 'application/json'};

  static Future<Map<String, dynamic>> send(
    Future<http.Response> Function() call,
  ) async {
    try {
      final res = await call().timeout(const Duration(seconds: 20));
      var body = <String, dynamic>{};
      try {
        final d = jsonDecode(res.body);
        if (d is Map) body = d.cast<String, dynamic>();
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ScanException(
          body['error']?.toString() ?? 'Erreur serveur (${res.statusCode}).',
        );
      }
      return body;
    } on TimeoutException {
      throw ScanException(
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on SocketException {
      throw ScanException('Connexion impossible. Vérifiez votre réseau.');
    } on http.ClientException {
      throw ScanException('Connexion impossible. Vérifiez votre réseau.');
    }
  }

  static Future<Map<String, dynamic>> get(
    String path,
    Map<String, String> query,
  ) => send(() => http.get(uri(path, query)));

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) => send(
    () => http.post(uri(path), headers: _headers, body: jsonEncode(body)),
  );

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) => send(
    () => http.patch(uri(path), headers: _headers, body: jsonEncode(body)),
  );
}

class ParcelService {
  static Future<List<Parcel>> list() async {
    final userId = await DeviceId.get();
    final body = await _Api.get('/api/parcels', {'user_id': userId});
    return ((body['parcels'] as List?) ?? [])
        .map((e) => Parcel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<Parcel> create({
    required String name,
    String? location,
    String? variety,
    int? treesCount,
  }) async {
    final userId = await DeviceId.get();
    final body = await _Api.post('/api/parcels', {
      'user_id': userId,
      'name': name,
      'location': location,
      'variety': variety,
      'trees_count': treesCount,
    });
    return Parcel.fromJson((body['parcel'] as Map).cast<String, dynamic>());
  }

  static Future<void> assignScan(String scanDbId, String parcelId) async {
    final userId = await DeviceId.get();
    await _Api.patch('/api/scans/$scanDbId/parcel', {
      'user_id': userId,
      'parcel_id': parcelId,
    });
  }
}

class ExpertService {
  static Future<void> request({
    String? scanDbId,
    required String phone,
    String? message,
  }) async {
    final userId = await DeviceId.get();
    await _Api.post('/api/expert-requests', {
      'user_id': userId,
      'scan_id': scanDbId,
      'phone': phone,
      'message': message,
    });
  }
}

class ScanService {
  static Future<ScanResult> scan(
    File image, {
    String lang = 'fr',
    String? userId,
  }) async {
    final uid = userId ?? await DeviceId.get();
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}/api/scan'),
          )
          ..fields['lang'] = lang
          ..fields['user_id'] = uid
          ..files.add(await http.MultipartFile.fromPath('image', image.path));

    try {
      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        String msg = 'Erreur serveur (${streamed.statusCode}).';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {}
        throw ScanException(msg);
      }
      return ScanResult.fromJson(
        (jsonDecode(body) as Map).cast<String, dynamic>(),
      );
    } on TimeoutException {
      throw ScanException(
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on SocketException {
      throw ScanException(
        'Connexion impossible. Vérifiez votre réseau et l’adresse du serveur.',
      );
    } on FormatException {
      throw ScanException('Réponse du serveur illisible.');
    }
  }
}
