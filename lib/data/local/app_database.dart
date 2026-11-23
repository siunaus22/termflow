import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Semesters, Goals, Tasks, Tags, TaskTags, SyncMeta],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaults();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = OFF');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  /// 首次启动时写入默认标签与默认示例学期，确保开箱即可体验四级计划联动
  Future<void> _seedDefaults() async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc();

    final defaultTags = [
      ('课程', '#4F6BED', 'book'),
      ('项目', '#0EA5E9', 'code'),
      ('竞赛', '#F59E0B', 'trophy'),
      ('生活', '#10B981', 'home'),
    ];

    await batch((b) {
      b.insertAll(
        tags,
        defaultTags.map(
          (t) => TagsCompanion.insert(
            id: uuid.v4(),
            name: t.$1,
            colorHex: Value(t.$2),
            iconName: Value(t.$3),
            createdAt: now,
            updatedAt: now,
            syncStatus: const Value('pending'),
          ),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      final today = DateTime.now();
      final isFall = today.month >= 8 || today.month == 1;
      final startYear = today.month == 1 ? today.year - 1 : today.year;
      final semStart = isFall ? DateTime(startYear, 9, 1) : DateTime(today.year, 2, 24);
      final semEnd = isFall ? DateTime(startYear + 1, 1, 20) : DateTime(today.year, 7, 10);
      final semName = isFall
          ? '$startYear-${startYear + 1} 第一学期'
          : '${today.year - 1}-${today.year} 第二学期';

      b.insert(
        semesters,
        SemestersCompanion.insert(
          id: uuid.v4(),
          name: semName,
          startDate: TermDateUtils.formatIsoDate(semStart),
          endDate: TermDateUtils.formatIsoDate(semEnd),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value('pending'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// 获取各同步表的待推送总数，用于同步状态指示灯角标
  Stream<int> watchPendingChangeCount() {
    return customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM semesters WHERE sync_status = 'pending') +
        (SELECT COUNT(*) FROM goals WHERE sync_status = 'pending') +
        (SELECT COUNT(*) FROM tasks WHERE sync_status = 'pending') +
        (SELECT COUNT(*) FROM tags WHERE sync_status = 'pending') +
        (SELECT COUNT(*) FROM task_tags WHERE sync_status = 'pending') AS total
      ''',
      readsFrom: {semesters, goals, tasks, tags, taskTags},
    ).watchSingle().map((row) => row.read<int>('total'));
  }

  /// 登录后把离线阶段创建（userId == null）的本地记录归属到当前登录账号
  Future<void> claimAnonymousRows(String uid) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(semesters)..where((t) => t.userId.isNull())).write(
        SemestersCompanion(
          userId: Value(uid),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await (update(goals)..where((t) => t.userId.isNull())).write(
        GoalsCompanion(
          userId: Value(uid),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await (update(tasks)..where((t) => t.userId.isNull())).write(
        TasksCompanion(
          userId: Value(uid),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await (update(tags)..where((t) => t.userId.isNull())).write(
        TagsCompanion(
          userId: Value(uid),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await (update(taskTags)..where((t) => t.userId.isNull())).write(
        TaskTagsCompanion(
          userId: Value(uid),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(dir.path, 'termflow.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}
