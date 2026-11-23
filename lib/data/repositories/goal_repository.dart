import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/app_database.dart';

/// 目标仓库：负责 学期 / 月度 / 周 三级目标 CRUD 及自底向上进度联动计算
class GoalRepository {
  GoalRepository(this._db, this._currentUserId);

  final AppDatabase _db;
  final String? Function() _currentUserId;
  static const _uuid = Uuid();

  Stream<List<GoalRow>> watchAllActiveGoals() {
    return (_db.select(_db.goals)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<GoalRow>> watchSemesterGoals(String? semesterId) {
    return (_db.select(_db.goals)
          ..where((t) {
            Expression<bool> cond =
                t.isDeleted.equals(false) & t.level.equals(GoalLevel.semester.value);
            if (semesterId != null) {
              cond = cond & t.semesterId.equals(semesterId);
            }
            return cond;
          })
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<GoalRow>> watchMonthlyGoals({
    required int year,
    required int month,
  }) {
    return (_db.select(_db.goals)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.level.equals(GoalLevel.monthly.value) &
                t.targetYear.equals(year) &
                t.targetMonth.equals(month),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<GoalRow>> watchWeeklyGoals({required String weekStartDate}) {
    return (_db.select(_db.goals)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.level.equals(GoalLevel.weekly.value) &
                t.weekStartDate.equals(weekStartDate),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<GoalRow?> getById(String id) {
    return (_db.select(_db.goals)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取从顶层（学期）到当前目标的完整溯源路径，用于在日任务上展示「学期 > 月 > 周」链条
  Future<List<GoalRow>> getGoalLineage(String goalId) async {
    final chain = <GoalRow>[];
    final visited = <String>{};
    String? currentId = goalId;

    while (currentId != null && visited.add(currentId) && chain.length < 5) {
      final row = await getById(currentId);
      if (row == null || row.isDeleted) break;
      chain.add(row);
      currentId = row.parentGoalId;
    }

    return chain.reversed.toList();
  }

  Future<String> createGoal({
    required GoalLevel level,
    required String title,
    String description = '',
    GoalCategory category = GoalCategory.academic,
    String? semesterId,
    String? parentGoalId,
    int? targetYear,
    int? targetMonth,
    int? targetWeekIndex,
    String? weekStartDate,
    String progressMode = 'auto',
    double manualProgress = 0.0,
    String? colorHex,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final uid = _currentUserId();
    final clampedManual = manualProgress.clamp(0.0, 1.0);

    await _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            id: id,
            userId: Value(uid),
            semesterId: Value(semesterId),
            parentGoalId: Value(parentGoalId),
            level: level.value,
            title: title.trim(),
            description: Value(description.trim()),
            category: Value(category.value),
            targetYear: Value(targetYear),
            targetMonth: Value(targetMonth),
            targetWeekIndex: Value(targetWeekIndex),
            weekStartDate: Value(weekStartDate),
            progressMode: Value(progressMode),
            manualProgress: Value(clampedManual),
            cachedProgress: Value(progressMode == 'manual' ? clampedManual : 0.0),
            colorHex: Value(colorHex ?? category.colorHex),
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value('pending'),
          ),
        );

    if (parentGoalId != null) {
      await recalculateProgressChain(parentGoalId);
    }
    return id;
  }

  Future<void> updateGoal({
    required String id,
    String? title,
    String? description,
    GoalCategory? category,
    String? parentGoalId,
    bool clearParentGoal = false,
    String? progressMode,
    double? manualProgress,
    String? status,
    String? colorHex,
  }) async {
    final existing = await getById(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final nextMode = progressMode ?? existing.progressMode;
    final nextManual = (manualProgress ?? existing.manualProgress).clamp(0.0, 1.0);
    final nextParentId = clearParentGoal ? null : (parentGoalId ?? existing.parentGoalId);

    await (_db.update(_db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        title: title != null ? Value(title.trim()) : const Value.absent(),
        description:
            description != null ? Value(description.trim()) : const Value.absent(),
        category: category != null ? Value(category.value) : const Value.absent(),
        parentGoalId: (clearParentGoal || parentGoalId != null)
            ? Value(nextParentId)
            : const Value.absent(),
        progressMode:
            progressMode != null ? Value(nextMode) : const Value.absent(),
        manualProgress:
            manualProgress != null ? Value(nextManual) : const Value.absent(),
        cachedProgress: nextMode == 'manual'
            ? Value(nextManual)
            : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await recalculateProgressChain(id);
    if (existing.parentGoalId != null && existing.parentGoalId != nextParentId) {
      await recalculateProgressChain(existing.parentGoalId);
    }
  }

  Future<void> softDeleteGoal(String id) async {
    final existing = await getById(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    await (_db.update(_db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    if (existing.parentGoalId != null) {
      await recalculateProgressChain(existing.parentGoalId);
    }
  }

  /// 自底向上沿 parentGoalId 链条重算目标进度（Task -> Weekly -> Monthly -> Semester）
  /// [markPending] 在本地用户操作时为 true；在云端 Pull 后的本地校准中设为 false 避免触发无效二次上传
  Future<void> recalculateProgressChain(
    String? startGoalId, {
    bool markPending = true,
  }) async {
    String? currentId = startGoalId;
    final visited = <String>{};

    while (currentId != null && visited.add(currentId)) {
      final goal = await getById(currentId);
      if (goal == null || goal.isDeleted) break;

      final double computed = await _computeGoalProgress(goal);
      final nextStatus = computed >= 0.999
          ? 'completed'
          : (goal.status == 'completed' ? 'active' : goal.status);

      final changed = (computed - goal.cachedProgress).abs() > 0.0005 ||
          nextStatus != goal.status;

      if (changed) {
        final now = DateTime.now().toUtc();
        await (_db.update(_db.goals)..where((t) => t.id.equals(goal.id))).write(
          GoalsCompanion(
            cachedProgress: Value(computed),
            status: Value(nextStatus),
            updatedAt: markPending ? Value(now) : const Value.absent(),
            syncStatus:
                markPending ? const Value('pending') : const Value.absent(),
          ),
        );
      }

      currentId = goal.parentGoalId;
    }
  }

  /// 云端增量同步完成后，按 Weekly -> Monthly -> Semester 顺序全量校准本地缓存进度
  Future<void> recalculateAllGoalsProgress({bool markPending = false}) async {
    for (final level in [
      GoalLevel.weekly.value,
      GoalLevel.monthly.value,
      GoalLevel.semester.value,
    ]) {
      final rows = await (_db.select(_db.goals)
            ..where((t) => t.isDeleted.equals(false) & t.level.equals(level)))
          .get();

      for (final goal in rows) {
        final computed = await _computeGoalProgress(goal);
        if ((computed - goal.cachedProgress).abs() > 0.0005) {
          await (_db.update(_db.goals)..where((t) => t.id.equals(goal.id)))
              .write(
            GoalsCompanion(
              cachedProgress: Value(computed),
              updatedAt:
                  markPending ? Value(DateTime.now().toUtc()) : const Value.absent(),
              syncStatus:
                  markPending ? const Value('pending') : const Value.absent(),
            ),
          );
        }
      }
    }
  }

  Future<double> _computeGoalProgress(GoalRow goal) async {
    if (goal.progressMode == 'manual') {
      return goal.manualProgress.clamp(0.0, 1.0);
    }

    final childGoals = await (_db.select(_db.goals)
          ..where((t) =>
              t.isDeleted.equals(false) & t.parentGoalId.equals(goal.id)))
        .get();

    final directTasks = await (_db.select(_db.tasks)
          ..where(
              (t) => t.isDeleted.equals(false) & t.goalId.equals(goal.id)))
        .get();

    double totalWeight = 0.0;
    double achievedWeight = 0.0;

    for (final child in childGoals) {
      totalWeight += 1.0;
      achievedWeight += child.cachedProgress.clamp(0.0, 1.0);
    }

    for (final task in directTasks) {
      final w = task.weight <= 0 ? 1.0 : task.weight.toDouble();
      totalWeight += w;
      if (task.isCompleted) {
        achievedWeight += w;
      }
    }

    if (totalWeight <= 0) return 0.0;
    return (achievedWeight / totalWeight).clamp(0.0, 1.0);
  }
}
