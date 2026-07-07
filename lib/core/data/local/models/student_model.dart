import 'dart:convert';

import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT PROFILE — EduTrack Family 2.0
// Perfil de un estudiante/hijo. Su id es también el uid con el que
// el dispositivo del niño se autentica (custom token).
// Espejo local de students/{studentId} en Firestore.
// ═══════════════════════════════════════════════════════════════

class StudentProfile extends Equatable {
  final String id;
  final String name;
  final String cedula;
  final String? grade;
  final int? avatarColor;
  final String? photoPath;
  final List<String> parentIds;
  final List<String> teacherIds;
  final bool locationSharingEnabled;
  final bool locationDeviceConfirmed;

  /// Alerta sísmica (complementa, no sustituye, las alertas nativas).
  /// Activada por defecto — la familia la apaga si no la quiere.
  final bool seismicAlertsEnabled;
  final double seismicMinMagnitude;

  final DateTime updatedAt;

  const StudentProfile({
    required this.id,
    required this.name,
    this.cedula = '',
    this.grade,
    this.avatarColor,
    this.photoPath,
    this.parentIds = const [],
    this.teacherIds = const [],
    this.locationSharingEnabled = false,
    this.locationDeviceConfirmed = false,
    this.seismicAlertsEnabled = true,
    this.seismicMinMagnitude = 4.5,
    required this.updatedAt,
  });

  /// Iniciales para el avatar (ej. "el estudiante Pérez" → "YP")
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  StudentProfile copyWith({
    String? name,
    String? cedula,
    String? grade,
    int? avatarColor,
    String? photoPath,
    List<String>? parentIds,
    List<String>? teacherIds,
    bool? locationSharingEnabled,
    bool? locationDeviceConfirmed,
    bool? seismicAlertsEnabled,
    double? seismicMinMagnitude,
    DateTime? updatedAt,
  }) {
    return StudentProfile(
      id: id,
      name: name ?? this.name,
      cedula: cedula ?? this.cedula,
      grade: grade ?? this.grade,
      avatarColor: avatarColor ?? this.avatarColor,
      photoPath: photoPath ?? this.photoPath,
      parentIds: parentIds ?? this.parentIds,
      teacherIds: teacherIds ?? this.teacherIds,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      locationDeviceConfirmed:
          locationDeviceConfirmed ?? this.locationDeviceConfirmed,
      seismicAlertsEnabled: seismicAlertsEnabled ?? this.seismicAlertsEnabled,
      seismicMinMagnitude: seismicMinMagnitude ?? this.seismicMinMagnitude,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── SQLite ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'cedula': cedula,
        'grade': grade,
        'avatar_color': avatarColor,
        'photo_path': photoPath,
        'parent_ids': jsonEncode(parentIds),
        'teacher_ids': jsonEncode(teacherIds),
        'location_sharing_enabled': locationSharingEnabled ? 1 : 0,
        'location_device_confirmed': locationDeviceConfirmed ? 1 : 0,
        'seismic_alerts_enabled': seismicAlertsEnabled ? 1 : 0,
        'seismic_min_magnitude': seismicMinMagnitude,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      cedula: map['cedula'] as String? ?? '',
      grade: map['grade'] as String?,
      avatarColor: map['avatar_color'] as int?,
      photoPath: map['photo_path'] as String?,
      parentIds: _parseStringList(map['parent_ids']),
      teacherIds: _parseStringList(map['teacher_ids']),
      locationSharingEnabled: (map['location_sharing_enabled'] ?? 0) == 1,
      locationDeviceConfirmed: (map['location_device_confirmed'] ?? 0) == 1,
      seismicAlertsEnabled: (map['seismic_alerts_enabled'] ?? 1) == 1,
      seismicMinMagnitude:
          (map['seismic_min_magnitude'] as num?)?.toDouble() ?? 4.5,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // ── Firestore ────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'cedula': cedula,
        'grade': grade,
        'avatarColor': avatarColor,
        'parentIds': parentIds,
        'teacherIds': teacherIds,
        'locationSharing': {
          'enabledByParent': locationSharingEnabled,
          'deviceConfirmed': locationDeviceConfirmed,
        },
        'seismicAlerts': {
          'enabled': seismicAlertsEnabled,
          'minMagnitude': seismicMinMagnitude,
        },
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudentProfile.fromFirestore(Map<String, dynamic> data, String id) {
    final locationSharing =
        (data['locationSharing'] as Map<String, dynamic>?) ?? const {};
    final seismicAlerts =
        (data['seismicAlerts'] as Map<String, dynamic>?) ?? const {};
    return StudentProfile(
      id: id,
      name: (data['name'] ?? '') as String,
      cedula: (data['cedula'] ?? '') as String,
      grade: data['grade'] as String?,
      avatarColor: data['avatarColor'] as int?,
      parentIds: _parseStringList(data['parentIds']),
      teacherIds: _parseStringList(data['teacherIds']),
      locationSharingEnabled:
          (locationSharing['enabledByParent'] ?? false) as bool,
      locationDeviceConfirmed:
          (locationSharing['deviceConfirmed'] ?? false) as bool,
      seismicAlertsEnabled: (seismicAlerts['enabled'] ?? true) as bool,
      seismicMinMagnitude:
          (seismicAlerts['minMagnitude'] as num?)?.toDouble() ?? 4.5,
      updatedAt: DateTime.tryParse((data['updatedAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  @override
  List<Object?> get props => [
        id,
        name,
        cedula,
        grade,
        avatarColor,
        photoPath,
        parentIds,
        teacherIds,
        locationSharingEnabled,
        locationDeviceConfirmed,
        seismicAlertsEnabled,
        seismicMinMagnitude,
        updatedAt,
      ];
}
