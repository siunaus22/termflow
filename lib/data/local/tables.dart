import 'package:drift/drift.dart';
import 'converters.dart';

/// 所有可同步表的公共 Mixin：满足离线优先 + LWW 双向同步要求
mixin SyncableTable on Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text().nullable()();
  TextColumn get createdAt => text().map(const UtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const UtcDateTimeConverter())();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  /// 仅本地维护，不推送至云端：'synced' | 'pending'
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 1. 学期表
@DataClassName('SemesterRow')
@TableIndex(name: 'idx_semesters_active', columns: {#isActive, #isDeleted})
@TableIndex(name: 'idx_semesters_sync', columns: {#syncStatus})
class Semesters extends Table with SyncableTable {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get startDate => text()(); // 'YYYY-MM-DD'
  TextColumn get endDate => text()();   // 'YYYY-MM-DD'
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get weekStartsOn => integer().withDefault(const Constant(1))();
}

/// 2. 目标表（学期 / 月度 / 周 三级目标统一树形建模）
@DataClassName('GoalRow')
@TableIndex(name: 'idx_goals_level_semester', columns: {#level, #semesterId, #isDeleted})
@TableIndex(name: 'idx_goals_parent', columns: {#parentGoalId, #isDeleted})
@TableIndex(name: 'idx_goals_period', columns: {#targetYear, #targetMonth, #weekStartDate})
@TableIndex(name: 'idx_goals_sync', columns: {#syncStatus})
class Goals extends Table with SyncableTable {
  TextColumn get semesterId => text().nullable()();
  TextColumn get parentGoalId => text().nullable()();
  /// 'semester' | 'monthly' | 'weekly'
  TextColumn get level => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  /// 'academic' | 'project' | 'competition' | 'life' | 'other'
  TextColumn get category => text().withDefault(const Constant('academic'))();

  IntColumn get targetYear => integer().nullable()();
  IntColumn get targetMonth => integer().nullable()();
  IntColumn get targetWeekIndex => integer().nullable()();
  TextColumn get weekStartDate => text().nullable()(); // 'YYYY-MM-DD'

  /// 'auto' | 'manual'
  TextColumn get progressMode => text().withDefault(const Constant('auto'))();
  RealColumn get manualProgress => real().withDefault(const Constant(0.0))();
  RealColumn get cachedProgress => real().withDefault(const Constant(0.0))();

  /// 'active' | 'completed' | 'archived'
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get colorHex => text().withDefault(const Constant('#4F6BED'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 3. 任务表（日计划待办 + 周计划未分配待办）
@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_scheduled', columns: {#scheduledDate, #isDeleted})
@TableIndex(name: 'idx_tasks_week', columns: {#weekStartDate, #isDeleted})
@TableIndex(name: 'idx_tasks_goal', columns: {#goalId, #isDeleted})
@TableIndex(name: 'idx_tasks_sync', columns: {#syncStatus})
class Tasks extends Table with SyncableTable {
  TextColumn get semesterId => text().nullable()();
  TextColumn get goalId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// 0=P0, 1=P1, 2=P2, 3=P3
  IntColumn get priority => integer().withDefault(const Constant(2))();
  IntColumn get estimatedMinutes => integer().nullable()();

  TextColumn get scheduledDate => text().nullable()(); // 'YYYY-MM-DD'
  TextColumn get weekStartDate => text().nullable()(); // 'YYYY-MM-DD'
  TextColumn get dueAt => text().map(const UtcDateTimeConverter()).nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get completedAt => text().map(const UtcDateTimeConverter()).nullable()();

  IntColumn get postponeCount => integer().withDefault(const Constant(0))();
  TextColumn get originalDate => text().nullable()(); // 'YYYY-MM-DD'

  IntColumn get weight => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 4. 标签表
@DataClassName('TagRow')
@TableIndex(name: 'idx_tags_sync', columns: {#syncStatus})
class Tags extends Table with SyncableTable {
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().withDefault(const Constant('#64748B'))();
  TextColumn get iconName => text().nullable()();
}

/// 5. 任务-标签多对多关联表
@DataClassName('TaskTagRow')
@TableIndex(name: 'idx_task_tags_task', columns: {#taskId, #isDeleted})
@TableIndex(name: 'idx_task_tags_tag', columns: {#tagId, #isDeleted})
@TableIndex(name: 'idx_task_tags_sync', columns: {#syncStatus})
class TaskTags extends Table with SyncableTable {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {taskId, tagId},
      ];
}

/// 6. 本地同步状态元数据表（不同步到云端）
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get tableNameKey => text()();
  TextColumn get lastPulledAt => text().nullable()();
  TextColumn get lastSyncedAt => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('idle'))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {tableNameKey};
}
