import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// TASK MODEL — EduTrack Family
// ═══════════════════════════════════════════════════════════════

enum TaskStatus { pending, completed, overdue, archived, pendingReview }

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:      return 'Pendiente';
      case TaskStatus.completed:    return 'Completada';
      case TaskStatus.overdue:      return 'Vencida';
      case TaskStatus.archived:     return 'Archivada';
      case TaskStatus.pendingReview: return 'En revisión';
    }
  }
}

class TaskModel extends Equatable {
  final String id;

  /// Estudiante dueño de la tarea (multi-tenant 2.0).
  /// '' solo durante la transición — toda tarea nueva debe llevarlo.
  final String studentId;

  /// uid del padre/profesor que asignó la tarea.
  final String? assignedBy;

  final String title;
  final String subject;
  final String? description;
  final String category;
  final DateTime dueDate;
  final TaskStatus status;

  // ─ Evidencia (multi-foto) ──────────────────────────────────
  final List<String> evidencePhotoPaths;

  final String? completionNote;

  // ─ Imágenes de referencia (admin) ────────────────────────
  final List<String> referenceImagePaths;

  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int notificationDaysBefore;
  final bool isDeleted;

  /// Historial de conversación (rechazos, reenvíos, aceptaciones)
  final List<ConversationEntry> conversationHistory;

  final bool _hasReferenceFlag;
  final bool _hasEvidenceFlag;

  const TaskModel({
    required this.id,
    this.studentId = '',
    this.assignedBy,
    required this.title,
    required this.subject,
    this.description,
    required this.category,
    required this.dueDate,
    this.status = TaskStatus.pending,
    this.evidencePhotoPaths = const [],
    bool hasEvidenceImages = false,
    this.completionNote,
    this.referenceImagePaths = const [],
    bool hasReferenceImages = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.notificationDaysBefore = 1,
    this.isDeleted = false,
    this.conversationHistory = const [],
  }) : _hasReferenceFlag = hasReferenceImages,
       _hasEvidenceFlag = hasEvidenceImages;

  // ─────────────────────────────────────────────────────────────
  // COMPUTED HELPERS
  // ─────────────────────────────────────────────────────────────

  int get daysLeft => EduDateUtils.daysUntil(dueDate);
  bool get isCompleted => status == TaskStatus.completed;
  bool get isPending => status == TaskStatus.pending;
  bool get isInReview => status == TaskStatus.pendingReview;
  bool get isUrgent => DateTime.now().isAfter(dueDate) && !isCompleted && !isInReview;
  bool get isOverdueTask => isUrgent;
  bool get isDueToday => EduDateUtils.isSameDay(dueDate, DateTime.now()) && DateTime.now().isBefore(dueDate) && !isCompleted && !isInReview;
  bool get hasEvidence => evidencePhotoPaths.isNotEmpty || _hasEvidenceFlag;
  bool get hasReference => referenceImagePaths.isNotEmpty || _hasReferenceFlag;

  String? get referenceImagePath =>
      referenceImagePaths.isNotEmpty ? referenceImagePaths.first : null;

  String? get photoEvidencePath =>
      evidencePhotoPaths.isNotEmpty ? evidencePhotoPaths.first : null;

  // ─────────────────────────────────────────────────────────────
  // COPY WITH
  // ─────────────────────────────────────────────────────────────

  TaskModel copyWith({
    String? id,
    String? studentId,
    String? assignedBy,
    String? title,
    String? subject,
    String? description,
    String? category,
    DateTime? dueDate,
    TaskStatus? status,
    List<String>? evidencePhotoPaths,
    String? completionNote,
    bool clearCompletionNote = false,
    List<String>? referenceImagePaths,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
    bool? isArchived,
    int? notificationDaysBefore,
    bool? isDeleted,
    List<ConversationEntry>? conversationHistory,
  }) {
    final newEv = evidencePhotoPaths ?? this.evidencePhotoPaths;
    final newRef = referenceImagePaths ?? this.referenceImagePaths;
    return TaskModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      assignedBy: assignedBy ?? this.assignedBy,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      evidencePhotoPaths: newEv,
      hasEvidenceImages: _hasEvidenceFlag || newEv.isNotEmpty,
      completionNote: clearCompletionNote ? null : (completionNote ?? this.completionNote),
      referenceImagePaths: newRef,
      hasReferenceImages: _hasReferenceFlag || newRef.isNotEmpty,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      notificationDaysBefore: notificationDaysBefore ?? this.notificationDaysBefore,
      isDeleted: isDeleted ?? this.isDeleted,
      conversationHistory: conversationHistory ?? this.conversationHistory,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SQLITE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'assigned_by': assignedBy,
      'title': title,
      'subject': subject,
      'description': description,
      'category': category,
      'due_date': EduDateUtils.toIso(dueDate),
      'status': status.index,
      'evidence_photo_paths': evidencePhotoPaths.isEmpty ? null : jsonEncode(evidencePhotoPaths),
      'has_evidence_images': _hasEvidenceFlag ? 1 : 0,
      'completion_note': completionNote,
      'reference_image_paths': referenceImagePaths.isEmpty ? null : jsonEncode(referenceImagePaths),
      'has_reference_images': _hasReferenceFlag ? 1 : 0,
      'completed_at': completedAt != null ? EduDateUtils.toIso(completedAt!) : null,
      'created_at': EduDateUtils.toIso(createdAt),
      'updated_at': EduDateUtils.toIso(updatedAt),
      'is_archived': isArchived ? 1 : 0,
      'notification_days_before': notificationDaysBefore,
      'is_deleted': isDeleted ? 1 : 0,
      'conversation_history': conversationHistory.isEmpty
          ? null
          : jsonEncode(conversationHistory.map((e) => e.toJson()).toList()),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String? ?? '',
      assignedBy: map['assigned_by'] as String?,
      title: map['title'] as String,
      subject: map['subject'] as String,
      description: map['description'] as String?,
      category: map['category'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: TaskStatus.values[map['status'] as int],
      evidencePhotoPaths: _parsePhotoPaths(map),
      hasEvidenceImages: (map['has_evidence_images'] as int? ?? 0) == 1,
      completionNote: map['completion_note'] as String?,
      referenceImagePaths: _parseReferencePaths(map['reference_image_paths']),
      hasReferenceImages: (map['has_reference_images'] as int? ?? 0) == 1,
      completedAt:
          map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isArchived: (map['is_archived'] as int) == 1,
      notificationDaysBefore: map['notification_days_before'] as int? ?? 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      conversationHistory: _parseConversationHistory(map['conversation_history']),
    );
  }

  static List<String> _parsePhotoPaths(Map<String, dynamic> map) {
    final jsonStr = map['evidence_photo_paths'] as String?;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List;
        return list.cast<String>();
      } catch (_) {}
    }
    return [];
  }

  static List<String> _parseReferencePaths(dynamic raw) {
    if (raw == null) return [];
    if (raw is! String || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<String>();
    } catch (_) {
      return [raw];
    }
  }

  static List<ConversationEntry> _parseConversationHistory(dynamic raw) {
    if (raw == null) return [];
    if (raw is! String || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ConversationEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FIRESTORE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'assigned_by': assignedBy,
      'title': title,
      'subject': subject,
      'description': description,
      'category': category,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'evidence_photo_paths': const <String>[],
      'has_evidence_images': _hasEvidenceFlag || evidencePhotoPaths.isNotEmpty,
      'completion_note': completionNote,
      'reference_image_paths': const <String>[],
      'has_reference_images': _hasReferenceFlag || referenceImagePaths.isNotEmpty,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_archived': isArchived,
      'notification_days_before': notificationDaysBefore,
      'is_deleted': isDeleted,
      'conversation_history':
          conversationHistory.map((e) => e.toJson()).toList(),
    };
  }

  /// [studentId] viene de la ruta students/{studentId}/tasks/{id},
  /// no del documento (fuente de verdad: la ruta).
  factory TaskModel.fromFirestore(Map<String, dynamic> data, String id,
      {String studentId = ''}) {
    TaskStatus parseStatus(String name) {
      return TaskStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TaskStatus.pending,
      );
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    List<String> parsePhotos() {
      final list = data['evidence_photo_paths'];
      return list is List ? list.cast<String>() : [];
    }

    List<String> parseRefPaths() {
      final list = data['reference_image_paths'];
      return list is List ? list.cast<String>() : [];
    }

    List<ConversationEntry> parseConversation() {
      final raw = data['conversation_history'];
      if (raw is List) {
        return raw
            .map((e) => ConversationEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return TaskModel(
      id: id,
      studentId: studentId,
      assignedBy: data['assigned_by'] as String?,
      title: data['title'] as String? ?? 'Sin título',
      subject: data['subject'] as String? ?? 'Sin materia',
      description: data['description'] as String?,
      category: data['category'] as String? ?? 'Tarea',
      dueDate: DateTime.parse(data['due_date'] as String? ?? DateTime.now().toIso8601String()),
      status: parseStatus(data['status'] as String? ?? 'pending'),
      evidencePhotoPaths: parsePhotos(),
      hasEvidenceImages: data['has_evidence_images'] as bool? ?? false,
      completionNote: data['completion_note'] as String?,
      referenceImagePaths: parseRefPaths(),
      hasReferenceImages: data['has_reference_images'] as bool? ?? false,
      completedAt:
          data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
      createdAt: DateTime.parse(data['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(data['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      isArchived: parseBool(data['is_archived']),
      notificationDaysBefore: data['notification_days_before'] as int? ?? 1,
      isDeleted: parseBool(data['is_deleted']),
      conversationHistory: parseConversation(),
    );
  }

  @override
  List<Object?> get props =>
      [id, studentId, title, subject, dueDate, status, isArchived, isDeleted];
}

// ═══════════════════════════════════════════════════════════════
// CONVERSATION ENTRY — historial de conversación tarea
// ═══════════════════════════════════════════════════════════════

class ConversationEntry {
  final String author; // 'admin' | 'student' | 'system'
  final String type;   // 'reject' | 'resubmit' | 'accept' | 'system'
  final String? text;
  final List<String> photoPaths;
  final DateTime timestamp;

  const ConversationEntry({
    required this.author,
    required this.type,
    this.text,
    this.photoPaths = const [],
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'author': author,
        'type': type,
        'text': text,
        'photoPaths': photoPaths,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ConversationEntry.fromJson(Map<String, dynamic> json) {
    return ConversationEntry(
      author: json['author'] as String? ?? 'system',
      type: json['type'] as String? ?? 'system',
      text: json['text'] as String?,
      photoPaths: (json['photoPaths'] as List?)?.cast<String>() ?? [],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  bool get isFromAdmin => author == 'admin';
  bool get isFromStudent => author == 'student';
}
