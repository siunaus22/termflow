import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class TagRepository {
  TagRepository(this._db, this._currentUserId);

  final AppDatabase _db;
  final String? Function() _currentUserId;
  static const _uuid = Uuid();

  Stream<List<TagRow>> watchAllTags() {
    return (_db.select(_db.tags)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  /// 一次性响应式映射所有 taskId -> List<TagRow>，避免列表渲染 N+1 查询
  Stream<Map<String, List<TagRow>>> watchTaskTagsMap() {
    final query = _db.select(_db.taskTags).join([
      innerJoin(
        _db.tags,
        _db.tags.id.equalsExp(_db.taskTags.tagId),
      ),
    ])
      ..where(
        _db.taskTags.isDeleted.equals(false) & _db.tags.isDeleted.equals(false),
      );

    return query.watch().map((rows) {
      final result = <String, List<TagRow>>{};
      for (final row in rows) {
        final link = row.readTable(_db.taskTags);
        final tag = row.readTable(_db.tags);
        result.putIfAbsent(link.taskId, () => []).add(tag);
      }
      return result;
    });
  }

  Future<String> createTag({
    required String name,
    String colorHex = '#64748B',
    String? iconName,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: id,
            userId: Value(_currentUserId()),
            name: name.trim(),
            colorHex: Value(colorHex),
            iconName: Value(iconName),
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value('pending'),
          ),
        );
    return id;
  }

  Future<void> softDeleteTag(String id) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await (_db.update(_db.taskTags)..where((t) => t.tagId.equals(id))).write(
        TaskTagsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  /// 更新单个任务的标签集合（复用已有 (taskId, tagId) 行 ID，避免同步唯一约束冲突）
  Future<void> setTagsForTask(String taskId, List<String> nextTagIds) async {
    final now = DateTime.now().toUtc();
    final uid = _currentUserId();
    final nextSet = nextTagIds.toSet();

    await _db.transaction(() async {
      final existingLinks = await (_db.select(_db.taskTags)
            ..where((t) => t.taskId.equals(taskId)))
          .get();

      final existingByTag = {for (final l in existingLinks) l.tagId: l};

      // 软删除取消勾选的标签关联
      for (final link in existingLinks) {
        if (!nextSet.contains(link.tagId) && !link.isDeleted) {
          await (_db.update(_db.taskTags)..where((t) => t.id.equals(link.id)))
              .write(
            TaskTagsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
              syncStatus: const Value('pending'),
            ),
          );
        }
      }

      // 恢复或新增勾选的标签关联
      for (final tagId in nextSet) {
        final existing = existingByTag[tagId];
        if (existing != null) {
          if (existing.isDeleted) {
            await (_db.update(_db.taskTags)
                  ..where((t) => t.id.equals(existing.id)))
                .write(
              TaskTagsCompanion(
                isDeleted: const Value(false),
                updatedAt: Value(now),
                syncStatus: const Value('pending'),
              ),
            );
          }
        } else {
          await _db.into(_db.taskTags).insert(
                TaskTagsCompanion.insert(
                  id: _uuid.v4(),
                  userId: Value(uid),
                  taskId: taskId,
                  tagId: tagId,
                  createdAt: now,
                  updatedAt: now,
                  syncStatus: const Value('pending'),
                ),
              );
        }
      }
    });
  }
}
