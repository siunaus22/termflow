import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../repositories/goal_repository.dart';
import 'sync_mapper.dart';

class SyncResult {
  const SyncResult({
    required this.success,
    this.pulledCount = 0,
    this.pushedCount = 0,
    this.syncedAt,
    this.errorMessage,
  });

  final bool success;
  final int pulledCount;
  final int pushedCount;
  final DateTime? syncedAt;
  final String? errorMessage;
}

/// 离线优先双向增量同步引擎（Pull -> Local LWW Merge -> Push Pending）
///
/// 拓扑同步顺序：semesters -> goals (semester/monthly/weekly) -> tags -> tasks -> task_tags
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required GoalRepository goalRepository,
    required SupabaseClient? Function() getClient,
  })  : _db = db,
        _goalRepo = goalRepository,
        _getClient = getClient;

  final AppDatabase _db;
  final GoalRepository _goalRepo;
  final SupabaseClient? Function() _getClient;

  static const _pageSize = 500;
  static const _pushBatchSize = 100;

  bool _isSyncing = false;
  bool _pendingResync = false;

  bool get isSyncing => _isSyncing;

  /// 执行完整双向增量同步
  Future<SyncResult> syncAll() async {
    final client = _getClient();
    if (client == null) {
      return const SyncResult(
        success: false,
        errorMessage: '尚未配置 Supabase URL / Anon Key（当前处于纯离线模式）',
      );
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return const SyncResult(
        success: false,
        errorMessage: '请先登录账号后再同步云端数据',
      );
    }

    if (_isSyncing) {
      _pendingResync = true;
      return const SyncResult(success: true);
    }

    _isSyncing = true;
    int totalPulled = 0;
    int totalPushed = 0;

    try {
      final uid = user.id;

      // 0. 将离线阶段创建的匿名记录归属到当前账号
      await _db.claimAnonymousRows(uid);

      // 1. PULL 阶段：按依赖顺序增量拉取云端变更并执行本地 LWW 合并
      final pulledSemesters = await _pullSemesters(client, uid);
      final pulledGoals = await _pullGoals(client, uid);
      final pulledTags = await _pullTags(client, uid);
      final pulledTasks = await _pullTasks(client, uid);
      final pulledTaskTags = await _pullTaskTags(client, uid);

      totalPulled = pulledSemesters +
          pulledGoals +
          pulledTags +
          pulledTasks +
          pulledTaskTags;

      // 2. PUSH 阶段：按拓扑顺序推送所有本地 pending 变更
      totalPushed += await _pushSemesters(client, uid);
      totalPushed += await _pushGoals(client, uid);
      totalPushed += await _pushTags(client, uid);
      totalPushed += await _pushTasks(client, uid);
      totalPushed += await _pushTaskTags(client, uid);

      // 3. 若本次拉取了远程目标或任务，静默校准本地缓存进度百分比
      if (pulledGoals > 0 || pulledTasks > 0) {
        await _goalRepo.recalculateAllGoalsProgress(markPending: false);
      }

      return SyncResult(
        success: true,
        pulledCount: totalPulled,
        pushedCount: totalPushed,
        syncedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        pulledCount: totalPulled,
        pushedCount: totalPushed,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
      if (_pendingResync) {
        _pendingResync = false;
        Future.microtask(syncAll);
      }
    }
  }

  /// 切换账号或强制全量重同步时重置本地游标
  Future<void> resetSyncCursors() async {
    await _db.delete(_db.syncMeta).go();
  }

  // =========================================================================
  // 同步游标管理 (sync_meta)
  // =========================================================================

  Future<String?> _getLastPulledAt(String tableName) async {
    final row = await (_db.select(_db.syncMeta)
          ..where((t) => t.tableNameKey.equals(tableName)))
        .getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<void> _saveSyncMeta({
    required String tableName,
    String? lastPulledAt,
    String status = 'idle',
    String? error,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _db.into(_db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion(
            tableNameKey: Value(tableName),
            lastPulledAt: lastPulledAt != null
                ? Value(lastPulledAt)
                : const Value.absent(),
            lastSyncedAt: Value(nowIso),
            status: Value(status),
            lastError: Value(error),
          ),
        );
  }

  /// 通用分页增量拉取：按 server_updated_at > cursor 顺序拉取，彻底避免时钟偏差漏数据
  Future<List<Map<String, dynamic>>> _fetchRemoteDelta(
    SupabaseClient client,
    String tableName,
    String uid,
    String? lastPulledAt,
  ) async {
    final collected = <Map<String, dynamic>>[];
    String? cursor = lastPulledAt;

    while (true) {
      var filter = client.from(tableName).select().eq('user_id', uid);
      if (cursor != null) {
        filter = filter.gt('server_updated_at', cursor);
      }

      final response = await filter
          .order('server_updated_at', ascending: true)
          .limit(_pageSize);

      final batch = (response as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (batch.isEmpty) break;
      collected.addAll(batch);

      final lastCursor = batch.last['server_updated_at'] as String?;
      if (batch.length < _pageSize || lastCursor == null || lastCursor == cursor) {
        break;
      }
      cursor = lastCursor;
    }

    return collected;
  }

  // =========================================================================
  // PULL 实现（每表独立事务 + LWW 合并）
  // =========================================================================

  Future<int> _pullSemesters(SupabaseClient client, String uid) async {
    const table = 'semesters';
    final lastCursor = await _getLastPulledAt(table);
    final rows = await _fetchRemoteDelta(client, table, uid, lastCursor);
    if (rows.isEmpty) return 0;

    String? maxServerTs = lastCursor;
    await _db.transaction(() async {
      for (final json in rows) {
        final id = json['id'] as String;
        final remoteUpdated = DateTime.parse(json['updated_at'] as String).toUtc();
        final existing = await (_db.select(_db.semesters)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null || !remoteUpdated.isBefore(existing.updatedAt)) {
          await _db
              .into(_db.semesters)
              .insertOnConflictUpdate(SyncMapper.semesterFromJson(json));
        }
        maxServerTs = (json['server_updated_at'] as String?) ?? maxServerTs;
      }
    });

    await _saveSyncMeta(tableName: table, lastPulledAt: maxServerTs);
    return rows.length;
  }

  Future<int> _pullGoals(SupabaseClient client, String uid) async {
    const table = 'goals';
    final lastCursor = await _getLastPulledAt(table);
    final rows = await _fetchRemoteDelta(client, table, uid, lastCursor);
    if (rows.isEmpty) return 0;

    String? maxServerTs = lastCursor;
    await _db.transaction(() async {
      for (final json in rows) {
        final id = json['id'] as String;
        final remoteUpdated = DateTime.parse(json['updated_at'] as String).toUtc();
        final existing = await (_db.select(_db.goals)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null || !remoteUpdated.isBefore(existing.updatedAt)) {
          await _db
              .into(_db.goals)
              .insertOnConflictUpdate(SyncMapper.goalFromJson(json));
        }
        maxServerTs = (json['server_updated_at'] as String?) ?? maxServerTs;
      }
    });

    await _saveSyncMeta(tableName: table, lastPulledAt: maxServerTs);
    return rows.length;
  }

  Future<int> _pullTags(SupabaseClient client, String uid) async {
    const table = 'tags';
    final lastCursor = await _getLastPulledAt(table);
    final rows = await _fetchRemoteDelta(client, table, uid, lastCursor);
    if (rows.isEmpty) return 0;

    String? maxServerTs = lastCursor;
    await _db.transaction(() async {
      for (final json in rows) {
        final id = json['id'] as String;
        final remoteUpdated = DateTime.parse(json['updated_at'] as String).toUtc();
        final existing = await (_db.select(_db.tags)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null || !remoteUpdated.isBefore(existing.updatedAt)) {
          await _db
              .into(_db.tags)
              .insertOnConflictUpdate(SyncMapper.tagFromJson(json));
        }
        maxServerTs = (json['server_updated_at'] as String?) ?? maxServerTs;
      }
    });

    await _saveSyncMeta(tableName: table, lastPulledAt: maxServerTs);
    return rows.length;
  }

  Future<int> _pullTasks(SupabaseClient client, String uid) async {
    const table = 'tasks';
    final lastCursor = await _getLastPulledAt(table);
    final rows = await _fetchRemoteDelta(client, table, uid, lastCursor);
    if (rows.isEmpty) return 0;

    String? maxServerTs = lastCursor;
    await _db.transaction(() async {
      for (final json in rows) {
        final id = json['id'] as String;
        final remoteUpdated = DateTime.parse(json['updated_at'] as String).toUtc();
        final existing = await (_db.select(_db.tasks)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null || !remoteUpdated.isBefore(existing.updatedAt)) {
          await _db
              .into(_db.tasks)
              .insertOnConflictUpdate(SyncMapper.taskFromJson(json));
        }
        maxServerTs = (json['server_updated_at'] as String?) ?? maxServerTs;
      }
    });

    await _saveSyncMeta(tableName: table, lastPulledAt: maxServerTs);
    return rows.length;
  }

  Future<int> _pullTaskTags(SupabaseClient client, String uid) async {
    const table = 'task_tags';
    final lastCursor = await _getLastPulledAt(table);
    final rows = await _fetchRemoteDelta(client, table, uid, lastCursor);
    if (rows.isEmpty) return 0;

    String? maxServerTs = lastCursor;
    await _db.transaction(() async {
      for (final json in rows) {
        final id = json['id'] as String;
        final remoteUpdated = DateTime.parse(json['updated_at'] as String).toUtc();
        final existing = await (_db.select(_db.taskTags)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null || !remoteUpdated.isBefore(existing.updatedAt)) {
          await _db
              .into(_db.taskTags)
              .insertOnConflictUpdate(SyncMapper.taskTagFromJson(json));
        }
        maxServerTs = (json['server_updated_at'] as String?) ?? maxServerTs;
      }
    });

    await _saveSyncMeta(tableName: table, lastPulledAt: maxServerTs);
    return rows.length;
  }

  // =========================================================================
  // PUSH 实现（分批 Upsert + 乐观并发校验 WHERE id = ? AND updated_at = ?）
  // =========================================================================

  Future<int> _pushSemesters(SupabaseClient client, String uid) async {
    final pending = await (_db.select(_db.semesters)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    if (pending.isEmpty) return 0;

    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(
        i,
        i + _pushBatchSize > pending.length ? pending.length : i + _pushBatchSize,
      );
      await client
          .from('semesters')
          .upsert(chunk.map((r) => SyncMapper.semesterToJson(r, uid)).toList());

      await _db.transaction(() async {
        for (final r in chunk) {
          await (_db.update(_db.semesters)
                ..where((t) =>
                    t.id.equals(r.id) & t.updatedAt.equalsValue(r.updatedAt)))
              .write(const SemestersCompanion(syncStatus: Value('synced')));
        }
      });
    }
    return pending.length;
  }

  Future<int> _pushGoals(SupabaseClient client, String uid) async {
    final pending = await (_db.select(_db.goals)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    if (pending.isEmpty) return 0;

    // 严格保证父级目标先于子级目标推送：semester(0) -> monthly(1) -> weekly(2)
    int levelRank(String level) => switch (level) {
          'semester' => 0,
          'monthly' => 1,
          _ => 2,
        };
    pending.sort((a, b) => levelRank(a.level).compareTo(levelRank(b.level)));

    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(
        i,
        i + _pushBatchSize > pending.length ? pending.length : i + _pushBatchSize,
      );
      await client
          .from('goals')
          .upsert(chunk.map((r) => SyncMapper.goalToJson(r, uid)).toList());

      await _db.transaction(() async {
        for (final r in chunk) {
          await (_db.update(_db.goals)
                ..where((t) =>
                    t.id.equals(r.id) & t.updatedAt.equalsValue(r.updatedAt)))
              .write(const GoalsCompanion(syncStatus: Value('synced')));
        }
      });
    }
    return pending.length;
  }

  Future<int> _pushTags(SupabaseClient client, String uid) async {
    final pending = await (_db.select(_db.tags)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    if (pending.isEmpty) return 0;

    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(
        i,
        i + _pushBatchSize > pending.length ? pending.length : i + _pushBatchSize,
      );
      await client
          .from('tags')
          .upsert(chunk.map((r) => SyncMapper.tagToJson(r, uid)).toList());

      await _db.transaction(() async {
        for (final r in chunk) {
          await (_db.update(_db.tags)
                ..where((t) =>
                    t.id.equals(r.id) & t.updatedAt.equalsValue(r.updatedAt)))
              .write(const TagsCompanion(syncStatus: Value('synced')));
        }
      });
    }
    return pending.length;
  }

  Future<int> _pushTasks(SupabaseClient client, String uid) async {
    final pending = await (_db.select(_db.tasks)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    if (pending.isEmpty) return 0;

    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(
        i,
        i + _pushBatchSize > pending.length ? pending.length : i + _pushBatchSize,
      );
      await client
          .from('tasks')
          .upsert(chunk.map((r) => SyncMapper.taskToJson(r, uid)).toList());

      await _db.transaction(() async {
        for (final r in chunk) {
          await (_db.update(_db.tasks)
                ..where((t) =>
                    t.id.equals(r.id) & t.updatedAt.equalsValue(r.updatedAt)))
              .write(const TasksCompanion(syncStatus: Value('synced')));
        }
      });
    }
    return pending.length;
  }

  Future<int> _pushTaskTags(SupabaseClient client, String uid) async {
    final pending = await (_db.select(_db.taskTags)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    if (pending.isEmpty) return 0;

    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(
        i,
        i + _pushBatchSize > pending.length ? pending.length : i + _pushBatchSize,
      );
      await client
          .from('task_tags')
          .upsert(chunk.map((r) => SyncMapper.taskTagToJson(r, uid)).toList());

      await _db.transaction(() async {
        for (final r in chunk) {
          await (_db.update(_db.taskTags)
                ..where((t) =>
                    t.id.equals(r.id) & t.updatedAt.equalsValue(r.updatedAt)))
              .write(const TaskTagsCompanion(syncStatus: Value('synced')));
        }
      });
    }
    return pending.length;
  }
}
