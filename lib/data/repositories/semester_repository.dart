import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class SemesterRepository {
  SemesterRepository(this._db, this._currentUserId);

  final AppDatabase _db;
  final String? Function() _currentUserId;
  static const _uuid = Uuid();

  Stream<List<SemesterRow>> watchAll() {
    return (_db.select(_db.semesters)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<SemesterRow?> watchActive() {
    return (_db.select(_db.semesters)
          ..where((t) => t.isDeleted.equals(false) & t.isActive.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<SemesterRow?> getActive() {
    return (_db.select(_db.semesters)
          ..where((t) => t.isDeleted.equals(false) & t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String> createSemester({
    required String name,
    required String startDate,
    required String endDate,
    bool setActive = true,
    int weekStartsOn = 1,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final uid = _currentUserId();

    await _db.transaction(() async {
      if (setActive) {
        await (_db.update(_db.semesters)
              ..where((t) => t.isActive.equals(true) & t.isDeleted.equals(false)))
            .write(
          SemestersCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      }

      await _db.into(_db.semesters).insert(
            SemestersCompanion.insert(
              id: id,
              userId: Value(uid),
              name: name.trim(),
              startDate: startDate,
              endDate: endDate,
              isActive: Value(setActive),
              weekStartsOn: Value(weekStartsOn),
              createdAt: now,
              updatedAt: now,
              syncStatus: const Value('pending'),
            ),
          );
    });

    return id;
  }

  Future<void> updateSemester({
    required String id,
    String? name,
    String? startDate,
    String? endDate,
    bool? isActive,
  }) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      if (isActive == true) {
        await (_db.update(_db.semesters)
              ..where((t) => t.isActive.equals(true) & t.id.isNotValue(id)))
            .write(
          SemestersCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      }

      await (_db.update(_db.semesters)..where((t) => t.id.equals(id))).write(
        SemestersCompanion(
          name: name != null ? Value(name.trim()) : const Value.absent(),
          startDate: startDate != null ? Value(startDate) : const Value.absent(),
          endDate: endDate != null ? Value(endDate) : const Value.absent(),
          isActive: isActive != null ? Value(isActive) : const Value.absent(),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  Future<void> setActiveSemester(String id) =>
      updateSemester(id: id, isActive: true);

  Future<void> softDeleteSemester(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.semesters)..where((t) => t.id.equals(id))).write(
      SemestersCompanion(
        isActive: const Value(false),
        isDeleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }
}
