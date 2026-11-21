import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/activity.dart';
import 'activity_service.dart';

/// Version réelle (Node/Express + Supabase).
/// Nécessite `http` dans pubspec.yaml :  flutter pub add http
///
/// Utilisation :
///   CalendrierScreen(
///     service: HttpActivityService(
///       baseUrl: 'http://10.0.2.2:5000',   // émulateur Android -> PC
///       getToken: () async => <ton JWT Supabase>,
///     ),
///   )
///
/// ⚠️ Hypothèses à vérifier avec tes autres modules :
///   GET /api/exploitations -> [{id, name}]
///   GET /api/parcels       -> [{id, name, variety, exploitation_id}]
class HttpActivityService implements ActivityService {
  HttpActivityService({required this.baseUrl, required this.getToken});

  final String baseUrl;
  final Future<String?> Function() getToken;

  Future<Map<String, String>> _headers() async {
    final t = await getToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  dynamic _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  @override
  Future<List<Activity>> list({String? parcelId}) async {
    final r = await http.get(
      _u('/api/activities', parcelId == null ? null : {'parcel_id': parcelId}),
      headers: await _headers(),
    );
    final data = _decode(r) as List;
    return data
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Activity> create(Activity draft) async {
    final r = await http.post(
      _u('/api/activities'),
      headers: await _headers(),
      body: jsonEncode(draft.toCreateJson()),
    );
    return Activity.fromJson(_decode(r) as Map<String, dynamic>);
  }

  @override
  Future<Activity> updateStatus(
    String id,
    ActivityStatus status, {
    int? progress,
  }) async {
    final r = await http.patch(
      _u('/api/activities/$id/status'),
      headers: await _headers(),
      body: jsonEncode({
        'status': status.api,
        if (progress != null) 'progress': progress,
      }),
    );
    return Activity.fromJson(_decode(r) as Map<String, dynamic>);
  }

  @override
  Future<PhenologyInfo?> phenology() async {
    final r = await http.get(
      _u('/api/activities/phenology'),
      headers: await _headers(),
    );
    final data = _decode(r);
    return data == null
        ? null
        : PhenologyInfo.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Option>> exploitations() async {
    final r = await http.get(
      _u('/api/exploitations'),
      headers: await _headers(),
    );
    final data = _decode(r) as List;
    return data
        .map(
          (e) => Option(
            id: e['id'].toString(),
            label: (e['name'] ?? '') as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<Option>> parcels() async {
    final r = await http.get(_u('/api/parcels'), headers: await _headers());
    final data = _decode(r) as List;
    return data.map((e) {
      final name = (e['name'] ?? '') as String;
      final variety = e['variety'] as String?;
      return Option(
        id: e['id'].toString(),
        label: variety == null || variety.isEmpty ? name : '$name - $variety',
        parentId: e['exploitation_id']?.toString(),
      );
    }).toList();
  }
}
