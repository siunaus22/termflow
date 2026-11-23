import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// 负责 Drift 本地数据行与 Supabase PostgreSQL JSON 之间的双向转换
/// 注意：不上传本地专用的 sync_status，也不主动覆写云端触发器维护的 server_updated_at
class SyncMapper {
  SyncMapper._();

  static DateTime _parseUtc(dynamic raw) =>
      DateTime.parse(raw as String).toUtc();

  static DateTime? _parseUtcOrNull(dynamic raw) =>
      raw == null ? null : DateTime.parse(raw as String).toUtc();

  static String? _dateOnly(dynamic raw) {
    if (raw == null) return null;
    final s = raw as String;
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  // ===================== Semesters =====================

  static Map<String, dynamic> semesterToJson(SemesterRow row, String uid) => {
        'id': row.id,
        'user_id': uid,
        'name': row.name,
        'start_date': row.startDate,
        'end_date': row.endDate,
        'is_active': row.isActive,
        'week_starts_on': row.weekStartsOn,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_deleted': row.isDeleted,
      };

  static SemestersCompanion semesterFromJson(Map<String, dynamic> json) =>
      SemestersCompanion(
        id: Value(json['id'] as String),
        userId: Value(json['user_id'] as String?),
        name: Value(json['name'] as String),
        startDate: Value(_dateOnly(json['start_date'])!),
        endDate: Value(_dateOnly(json['end_date'])!),
        isActive: Value((json['is_active'] as bool?) ?? false),
        weekStartsOn: Value((json['week_starts_on'] as num?)?.toInt() ?? 1),
        createdAt: Value(_parseUtc(json['created_at'])),
        updatedAt: Value(_parseUtc(json['updated_at'])),
        isDeleted: Value((json['is_deleted'] as bool?) ?? false),
        syncStatus: const Value('synced'),
      );

  // ===================== Goals =====================

  static Map<String, dynamic> goalToJson(GoalRow row, String uid) => {
        'id': row.id,
        'user_id': uid,
        'semester_id': row.semesterId,
        'parent_goal_id': row.parentGoalId,
        'level': row.level,
        'title': row.title,
        'description': row.description,
        'category': row.category,
        'target_year': row.targetYear,
        'target_month': row.targetMonth,
        'target_week_index': row.targetWeekIndex,
        'week_start_date': row.weekStartDate,
        'progress_mode': row.progressMode,
        'manual_progress': row.manualProgress,
        'cached_progress': row.cachedProgress,
        'status': row.status,
        'color_hex': row.colorHex,
        'sort_order': row.sortOrder,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_deleted': row.isDeleted,
      };

  static GoalsCompanion goalFromJson(Map<String, dynamic> json) =>
      GoalsCompanion(
        id: Value(json['id'] as String),
        userId: Value(json['user_id'] as String?),
        semesterId: Value(json['semester_id'] as String?),
        parentGoalId: Value(json['parent_goal_id'] as String?),
        level: Value(json['level'] as String),
        title: Value(json['title'] as String),
        description: Value((json['description'] as String?) ?? ''),
        category: Value((json['category'] as String?) ?? 'academic'),
        targetYear: Value((json['target_year'] as num?)?.toInt()),
        targetMonth: Value((json['target_month'] as num?)?.toInt()),
        targetWeekIndex: Value((json['target_week_index'] as num?)?.toInt()),
        weekStartDate: Value(_dateOnly(json['week_start_date'])),
        progressMode: Value((json['progress_mode'] as String?) ?? 'auto'),
        manualProgress:
            Value((json['manual_progress'] as num?)?.toDouble() ?? 0.0),
        cachedProgress:
            Value((json['cached_progress'] as num?)?.toDouble() ?? 0.0),
        status: Value((json['status'] as String?) ?? 'active'),
        colorHex: Value((json['color_hex'] as String?) ?? '#4F6BED'),
        sortOrder: Value((json['sort_order'] as num?)?.toInt() ?? 0),
        createdAt: Value(_parseUtc(json['created_at'])),
        updatedAt: Value(_parseUtc(json['updated_at'])),
        isDeleted: Value((json['is_deleted'] as bool?) ?? false),
        syncStatus: const Value('synced'),
      );

  // ===================== Tasks =====================

  static Map<String, dynamic> taskToJson(TaskRow row, String uid) => {
        'id': row.id,
        'user_id': uid,
        'semester_id': row.semesterId,
        'goal_id': row.goalId,
        'title': row.title,
        'notes': row.notes,
        'priority': row.priority,
        'estimated_minutes': row.estimatedMinutes,
        'scheduled_date': row.scheduledDate,
        'week_start_date': row.weekStartDate,
        'due_at': row.dueAt?.toUtc().toIso8601String(),
        'is_completed': row.isCompleted,
        'completed_at': row.completedAt?.toUtc().toIso8601String(),
        'postpone_count': row.postponeCount,
        'original_date': row.originalDate,
        'weight': row.weight,
        'sort_order': row.sortOrder,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_deleted': row.isDeleted,
      };

  static TasksCompanion taskFromJson(Map<String, dynamic> json) =>
      TasksCompanion(
        id: Value(json['id'] as String),
        userId: Value(json['user_id'] as String?),
        semesterId: Value(json['semester_id'] as String?),
        goalId: Value(json['goal_id'] as String?),
        title: Value(json['title'] as String),
        notes: Value((json['notes'] as String?) ?? ''),
        priority: Value((json['priority'] as num?)?.toInt() ?? 2),
        estimatedMinutes: Value((json['estimated_minutes'] as num?)?.toInt()),
        scheduledDate: Value(_dateOnly(json['scheduled_date'])),
        weekStartDate: Value(_dateOnly(json['week_start_date'])),
        dueAt: Value(_parseUtcOrNull(json['due_at'])),
        isCompleted: Value((json['is_completed'] as bool?) ?? false),
        completedAt: Value(_parseUtcOrNull(json['completed_at'])),
        postponeCount: Value((json['postpone_count'] as num?)?.toInt() ?? 0),
        originalDate: Value(_dateOnly(json['original_date'])),
        weight: Value((json['weight'] as num?)?.toInt() ?? 1),
        sortOrder: Value((json['sort_order'] as num?)?.toInt() ?? 0),
        createdAt: Value(_parseUtc(json['created_at'])),
        updatedAt: Value(_parseUtc(json['updated_at'])),
        isDeleted: Value((json['is_deleted'] as bool?) ?? false),
        syncStatus: const Value('synced'),
      );

  // ===================== Tags =====================

  static Map<String, dynamic> tagToJson(TagRow row, String uid) => {
        'id': row.id,
        'user_id': uid,
        'name': row.name,
        'color_hex': row.colorHex,
        'icon_name': row.iconName,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_deleted': row.isDeleted,
      };

  static TagsCompanion tagFromJson(Map<String, dynamic> json) => TagsCompanion(
        id: Value(json['id'] as String),
        userId: Value(json['user_id'] as String?),
        name: Value(json['name'] as String),
        colorHex: Value((json['color_hex'] as String?) ?? '#64748B'),
        iconName: Value(json['icon_name'] as String?),
        createdAt: Value(_parseUtc(json['created_at'])),
        updatedAt: Value(_parseUtc(json['updated_at'])),
        isDeleted: Value((json['is_deleted'] as bool?) ?? false),
        syncStatus: const Value('synced'),
      );

  // ===================== TaskTags =====================

  static Map<String, dynamic> taskTagToJson(TaskTagRow row, String uid) => {
        'id': row.id,
        'user_id': uid,
        'task_id': row.taskId,
        'tag_id': row.tagId,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_deleted': row.isDeleted,
      };

  static TaskTagsCompanion taskTagFromJson(Map<String, dynamic> json) =>
      TaskTagsCompanion(
        id: Value(json['id'] as String),
        userId: Value(json['user_id'] as String?),
        taskId: Value(json['task_id'] as String),
        tagId: Value(json['tag_id'] as String),
        createdAt: Value(_parseUtc(json['created_at'])),
        updatedAt: Value(_parseUtc(json['updated_at'])),
        isDeleted: Value((json['is_deleted'] as bool?) ?? false),
        syncStatus: const Value('synced'),
      );
}
