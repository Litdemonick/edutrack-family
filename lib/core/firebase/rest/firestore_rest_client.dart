import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:http/http.dart' as http;

import 'package:edutrack_family/features/auth/data/firebase_auth_repository.dart';
import 'package:edutrack_family/firebase_options.dart';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE REST CLIENT — EduTrack Family 2.0 (Windows/Linux)
// Códec de valores "Value" de la API REST de Firestore, portado
// 1:1 desde workers/edutrack-api/src/lib/firestore.js — misma
// codificación, pero autenticado con el ID token del usuario final
// (no la service account), así que firestore.rules se aplica
// exactamente igual que con el SDK nativo.
// ═══════════════════════════════════════════════════════════════

class FirestoreDoc {
  final String id;
  final String path;
  final Map<String, dynamic> data;
  final String? updateTime;
  const FirestoreDoc({
    required this.id,
    required this.path,
    required this.data,
    this.updateTime,
  });
}

class QueryFilter {
  final String field;
  final String op; // EQUAL | GREATER_THAN | GREATER_THAN_OR_EQUAL | ARRAY_CONTAINS ...
  final Object value;
  const QueryFilter(this.field, this.op, this.value);
}

class FirestoreRestException implements Exception {
  final int statusCode;
  final String message;
  FirestoreRestException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class FirestoreValueCodec {
  static Map<String, dynamic> toValue(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is String) return {'stringValue': v};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': v.toString()};
    if (v is double) return {'doubleValue': v};
    if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
    if (v is Timestamp) return {'timestampValue': v.toDate().toUtc().toIso8601String()};
    if (v is List) {
      return {
        'arrayValue': {'values': v.map(toValue).toList()}
      };
    }
    if (v is Map) {
      return {
        'mapValue': {
          'fields': v.map((k, val) => MapEntry(k.toString(), toValue(val)))
        }
      };
    }
    return {'stringValue': v.toString()};
  }

  static Object? fromValue(Map<String, dynamic>? value) {
    if (value == null) return null;
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('timestampValue')) {
      // Timestamp, no String — así el código que lee el doc no necesita
      // distinguir si vino del SDK nativo o de este cliente REST.
      return Timestamp.fromDate(DateTime.parse(value['timestampValue'] as String));
    }
    if (value.containsKey('arrayValue')) {
      final values =
          (value['arrayValue'] as Map<String, dynamic>?)?['values'] as List?;
      return (values ?? [])
          .map((v) => fromValue(v as Map<String, dynamic>))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      final fields =
          (value['mapValue'] as Map<String, dynamic>?)?['fields'] as Map?;
      return fromFields(fields?.cast<String, dynamic>());
    }
    return null;
  }

  static Map<String, dynamic> toFields(Map<String, dynamic> obj) {
    return obj.map((k, v) => MapEntry(k, toValue(v)));
  }

  static Map<String, dynamic> fromFields(Map<String, dynamic>? fields) {
    if (fields == null) return {};
    return fields.map(
        (k, v) => MapEntry(k, fromValue(v as Map<String, dynamic>?)));
  }

  static FirestoreDoc parseDoc(Map<String, dynamic> doc) {
    final name = doc['name'] as String;
    final id = name.split('/').last;
    return FirestoreDoc(
      id: id,
      path: name,
      data: fromFields(doc['fields'] as Map<String, dynamic>?),
      updateTime: doc['updateTime'] as String?,
    );
  }
}

class FirestoreRestClient {
  FirestoreRestClient._();
  static final FirestoreRestClient instance = FirestoreRestClient._();

  static final _projectId = DefaultFirebaseOptions.android.projectId;
  static String get _base =>
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuthRepository.instance.currentIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// GET de un documento por ruta relativa (ej. 'users/uid123'). Null si no existe.
  Future<FirestoreDoc?> getDoc(String relPath) async {
    final res = await http.get(Uri.parse('$_base/$relPath'), headers: await _headers());
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      throw FirestoreRestException(res.statusCode, 'Firestore GET $relPath: ${res.body}');
    }
    return FirestoreValueCodec.parseDoc(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET de una colección completa, sin filtro (ej. scheduleBlocks sin cursor).
  Future<List<FirestoreDoc>> getCollection(String relPath) async {
    final docs = <FirestoreDoc>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_base/$relPath').replace(queryParameters: {
        'pageSize': '300',
        if (pageToken != null) 'pageToken': pageToken,
      });
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode >= 400) {
        throw FirestoreRestException(res.statusCode, 'Firestore GET $relPath: ${res.body}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final rawDocs = (json['documents'] as List?) ?? const [];
      docs.addAll(rawDocs
          .map((d) => FirestoreValueCodec.parseDoc(d as Map<String, dynamic>)));
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
    return docs;
  }

  /// PATCH con merge (crea si no existe) — equivalente a set(merge:true).
  Future<FirestoreDoc> patchDoc(String relPath, Map<String, dynamic> data) async {
    final maskParams = data.keys
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeComponent(f)}')
        .join('&');
    final uri = Uri.parse('$_base/$relPath?$maskParams');
    final res = await http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode({'fields': FirestoreValueCodec.toFields(data)}),
    );
    if (res.statusCode >= 400) {
      throw FirestoreRestException(res.statusCode, 'Firestore PATCH $relPath: ${res.body}');
    }
    return FirestoreValueCodec.parseDoc(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteDoc(String relPath) async {
    final res = await http.delete(Uri.parse('$_base/$relPath'), headers: await _headers());
    if (res.statusCode >= 400 && res.statusCode != 404) {
      throw FirestoreRestException(res.statusCode, 'Firestore DELETE $relPath: ${res.body}');
    }
  }

  /// Query estructurada. Si [parentRelPath] es null, corre contra la
  /// raíz (ej. colección students); si no, contra la subcolección de
  /// ese documento padre (ej. students/{id}/tasks).
  Future<List<FirestoreDoc>> runQuery({
    String? parentRelPath,
    required String collectionId,
    List<QueryFilter> filters = const [],
    int? limit,
  }) async {
    final fieldFilters = filters
        .map((f) => {
              'fieldFilter': {
                'field': {'fieldPath': f.field},
                'op': f.op,
                'value': FirestoreValueCodec.toValue(f.value),
              }
            })
        .toList();

    Map<String, dynamic>? where;
    if (fieldFilters.length == 1) {
      where = fieldFilters.first;
    } else if (fieldFilters.length > 1) {
      where = {
        'compositeFilter': {'op': 'AND', 'filters': fieldFilters}
      };
    }

    final body = {
      'structuredQuery': {
        'from': [
          {'collectionId': collectionId}
        ],
        if (where != null) 'where': where,
        if (limit != null) 'limit': limit,
      }
    };

    final url = parentRelPath == null ? '$_base:runQuery' : '$_base/$parentRelPath:runQuery';
    final res = await http.post(Uri.parse(url), headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode >= 400) {
      throw FirestoreRestException(res.statusCode, 'Firestore runQuery $collectionId: ${res.body}');
    }
    final rows = jsonDecode(res.body) as List;
    return rows
        .where((r) => (r as Map<String, dynamic>).containsKey('document'))
        .map((r) => FirestoreValueCodec.parseDoc(
            (r as Map<String, dynamic>)['document'] as Map<String, dynamic>))
        .toList();
  }
}
