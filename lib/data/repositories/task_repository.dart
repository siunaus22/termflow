import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../core/utils/date_utils.dart';
import '../local/app_database.dart';
import 'goal_repository.dart';
import 'tag_repository.dart';

/// 任务仓库：日计划待办、周待办分配到日、昨日未完成一键顺延、自动联动上级目标进度
class TaskRepository {
  TaskRepository(
    this._db,
    this._goalRepo,
    this._tagRepo,
    this._currentUserId,
  );

  final AppDatabase _db;
  final GoalRepository _goalRepo;
  final TagRepository _tagRepo;
  final String? Function() _currentUserId;
  static const _uuid = Uuid();

  Stream<List<TaskRow>> watchTasksForDate(String isoDate) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.isDeleted.equals(false) & t.scheduledDate.equals(isoDate),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.isCompleted),
            (t) => OrderingTerm(expression: t.priority),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  /// 监听某周内的所有任务（包含未分配到具体某天的周待办 + 已分配到该周各天的任务）
  Stream<List<TaskRow>> watchTasksForWeek(String weekStartIso) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.isDeleted.equals(false) & t.weekStartDate.equals(weekStartIso),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.isCompleted),
            (t) => OrderingTerm(expression: t.priority),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  /// 监听某个月内的所有已排期任务（用于月历日期指示点与月度任务总览）
  Stream<List<TaskRow>> watchTasksForMonth(int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.isDeleted.equals(false) & t.scheduledDate.like('$prefix%'),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.scheduledDate),
            (t) => OrderingTerm(expression: t.priority),
          ]))
        .watch();
  }

  /// 监听昨天及之前尚未完成的日计划数量，用于顶部展示“一键顺延至今天”提示条
  Stream<List<TaskRow>> watchOverdueUnfinishedTasks(String todayIso) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.isCompleted.equals(false) &
                t.scheduledDate.isNotNull() &
                t.scheduledDate.isSmallerThanValue(todayIso),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.scheduledDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.priority),
          ]))
        .watch();
  }

  Stream<TaskRow?> watchTaskById(String id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<TaskRow?> getById(String id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> createTask({
    required String title,
    String notes = '',
    TaskPriority priority = TaskPriority.p2,
    int? estimatedMinutes,
    String? scheduledDate,
    String? weekStartDate,
    DateTime? dueAt,
    String? goalId,
    String? semesterId,
    List<String> tagIds = const [],
    int weight = 1,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final resolvedWeekStart = weekStartDate ??
        (scheduledDate != null
            ? TermDateUtils.startOfWeekIso(TermDateUtils.parseIsoDate(scheduledDate))
            : null);

    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            userId: Value(_currentUserId()),
            semesterId: Value(semesterId),
            goalId: Value(goalId),
            title: title.trim(),
            notes: Value(notes.trim()),
            priority: Value(priority.value),
            estimatedMinutes: Value(estimatedMinutes),
            scheduledDate: Value(scheduledDate),
            weekStartDate: Value(resolvedWeekStart),
            dueAt: Value(dueAt?.toUtc()),
            originalDate: Value(scheduledDate),
            weight: Value(weight < 1 ? 1 : weight),
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value('pending'),
          ),
        );

    if (tagIds.isNotEmpty) {
      await _tagRepo.setTagsForTask(id, tagIds);
    }

    if (goalId != null) {
      await _goalRepo.recalculateProgressChain(goalId);
    }

    return id;
  }

  Future<void> updateTask({
    required String id,
    String? title,
    String? notes,
    TaskPriority? priority,
    int? estimatedMinutes,
    bool clearEstimatedMinutes = false,
    String? scheduledDate,
    bool clearScheduledDate = false,
    String? weekStartDate,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? goalId,
    bool clearGoal = false,
    int? weight,
  }) async {
    final existing = await getById(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final nextScheduled =
        clearScheduledDate ? null : (scheduledDate ?? existing.scheduledDate);
    final nextWeekStart = weekStartDate ??
        (scheduledDate != null
            ? TermDateUtils.startOfWeekIso(TermDateUtils.parseIsoDate(scheduledDate))
            : existing.weekStartDate);
    final nextGoalId = clearGoal ? null : (goalId ?? existing.goalId);

    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: title != null ? Value(title.trim()) : const Value.absent(),
        notes: notes != null ? Value(notes.trim()) : const Value.absent(),
        priority: priority != null ? Value(priority.value) : const Value.absent(),
        estimatedMinutes: clearEstimatedMinutes
            ? const Value(null)
            : (estimatedMinutes != null
                ? Value(estimatedMinutes)
                : const Value.absent()),
        scheduledDate: (clearScheduledDate || scheduledDate != null)
            ? Value(nextScheduled)
            : const Value.absent(),
        weekStartDate: (weekStartDate != null || scheduledDate != null)
            ? Value(nextWeekStart)
            : const Value.absent(),
        dueAt: clearDueAt
            ? const Value(null)
            : (dueAt != null ? Value(dueAt.toUtc()) : const Value.absent()),
        goalId: (clearGoal || goalId != null)
            ? Value(nextGoalId)
            : const Value.absent(),
        weight: weight != null ? Value(weight < 1 ? 1 : weight) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    if (nextGoalId != null) {
      await _goalRepo.recalculateProgressChain(nextGoalId);
    }
    if (existing.goalId != null && existing.goalId != nextGoalId) {
      await _goalRepo.recalculateProgressChain(existing.goalId);
    }
  }

  /// 切换完成状态，并自动向上推进关联目标（周 -> 月 -> 学期）的完成百分比
  Future<void> toggleComplete(String taskId) async {
    final task = await getById(taskId);
    if (task == null || task.isDeleted) return;

    final now = DateTime.now().toUtc();
    final nextCompleted = !task.isCompleted;

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        isCompleted: Value(nextCompleted),
        completedAt: Value(nextCompleted ? now : null),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    if (task.goalId != null) {
      await _goalRepo.recalculateProgressChain(task.goalId);
    }
  }

  /// 周计划一键分配：将周待办分配到本周的具体某一天
  Future<void> assignTaskToDate(String taskId, String isoDate) async {
    final now = DateTime.now().toUtc();
    final weekStart =
        TermDateUtils.startOfWeekIso(TermDateUtils.parseIsoDate(isoDate));
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        scheduledDate: Value(isoDate),
        weekStartDate: Value(weekStart),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// 一键将昨日（或过去所有逾期）未完成的日计划顺延至今天
  Future<int> postponeOverdueToToday({bool onlyYesterday = false}) async {
    final todayIso = TermDateUtils.todayIso();
    final yesterdayIso = TermDateUtils.yesterdayIso();
    final todayWeekStart = TermDateUtils.startOfWeekIso(DateTime.now());
    final now = DateTime.now().toUtc();

    final overdueRows = await (_db.select(_db.tasks)
          ..where((t) {
            final base = t.isDeleted.equals(false) &
                t.isCompleted.equals(false) &
                t.scheduledDate.isNotNull();
            if (onlyYesterday) {
              return base & t.scheduledDate.equals(yesterdayIso);
            }
            return base & t.scheduledDate.isSmallerThanValue(todayIso);
          }))
        .get();

    if (overdueRows.isEmpty) return 0;

    await _db.transaction(() async {
      for (final task in overdueRows) {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id))).write(
          TasksCompanion(
            scheduledDate: Value(todayIso),
            weekStartDate: Value(todayWeekStart),
            originalDate: Value(task.originalDate ?? task.scheduledDate),
            postponeCount: Value(task.postponeCount + 1),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      }
    });

    return overdueRows.length;
  }

  /// 单条任务顺延一天（适配 Android 列表左滑顺延）
  Future<void> postponeTaskByOneDay(String taskId) async {
    final task = await getById(taskId);
    if (task == null) return;

    final baseDate = task.scheduledDate != null
        ? TermDateUtils.parseIsoDate(task.scheduledDate!)
        : DateTime.now();
    final nextDate = baseDate.add(const Duration(days: 1));
    final nextIso = TermDateUtils.formatIsoDate(nextDate);
    final nextWeekStart = TermDateUtils.startOfWeekIso(nextDate);
    final now = DateTime.now().toUtc();

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        scheduledDate: Value(nextIso),
        weekStartDate: Value(nextWeekStart),
        originalDate: Value(task.originalDate ?? task.scheduledDate),
        postponeCount: Value(task.postponeCount + 1),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> softDeleteTask(String taskId) async {
    final task = await getById(taskId);
    if (task == null) return;

    final now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    if (task.goalId != null) {
      await _goalRepo.recalculateProgressChain(task.goalId);
    }
  }
}
