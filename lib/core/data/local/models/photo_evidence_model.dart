import 'package:equatable/equatable.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// PHOTO EVIDENCE MODEL — EduTrack Family
// Representa la foto que Yordan toma como evidencia
// de que completó una tarea.
// ═══════════════════════════════════════════════════════════════

class PhotoEvidenceModel extends Equatable {
  final String id;
  final String taskId;
  final String localPath;
  final String? remoteUrl;
  final DateTime capturedAt;
  final bool isSyncedToCloud;

  const PhotoEvidenceModel({
    required this.id,
    required this.taskId,
    required this.localPath,
    this.remoteUrl,
    required this.capturedAt,
    this.isSyncedToCloud = false,
  });

  bool get isAvailable => localPath.isNotEmpty || remoteUrl != null;

  // Usa la ruta local si está disponible, si no la remota
  String? get displayPath => localPath.isNotEmpty ? localPath : remoteUrl;

  PhotoEvidenceModel copyWith({
    String? localPath,
    String? remoteUrl,
    bool? isSyncedToCloud,
  }) {
    return PhotoEvidenceModel(
      id: id,
      taskId: taskId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      capturedAt: capturedAt,
      isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SQLITE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'captured_at': EduDateUtils.toIso(capturedAt),
      'is_synced_to_cloud': isSyncedToCloud ? 1 : 0,
    };
  }

  factory PhotoEvidenceModel.fromMap(Map<String, dynamic> map) {
    return PhotoEvidenceModel(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      localPath: map['local_path'] as String? ?? '',
      remoteUrl: map['remote_url'] as String?,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      isSyncedToCloud: (map['is_synced_to_cloud'] as int) == 1,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FIRESTORE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'task_id': taskId,
      'remote_url': remoteUrl,
      'captured_at': capturedAt.toIso8601String(),
    };
  }

  factory PhotoEvidenceModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return PhotoEvidenceModel(
      id: id,
      taskId: data['task_id'] as String,
      localPath: '',
      remoteUrl: data['remote_url'] as String?,
      capturedAt: DateTime.parse(data['captured_at'] as String),
      isSyncedToCloud: true,
    );
  }

  @override
  List<Object?> get props => [id, taskId, capturedAt];
}
