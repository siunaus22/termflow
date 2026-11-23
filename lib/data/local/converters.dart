import 'package:drift/drift.dart';

/// 统一将 DateTime 以 UTC ISO-8601 字符串存储到 SQLite，
/// 保留毫秒/微秒精度，并可直接进行字典序比较与 Supabase TIMESTAMPTZ 对齐。
class UtcDateTimeConverter extends TypeConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb).toUtc();

  @override
  String toSql(DateTime value) => value.toUtc().toIso8601String();
}
