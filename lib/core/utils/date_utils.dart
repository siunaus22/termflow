import 'package:intl/intl.dart';

/// 统一日期与教学周工具（所有日期字符串格式均为 'YYYY-MM-DD'）
class TermDateUtils {
  TermDateUtils._();

  static final DateFormat _isoDateFmt = DateFormat('yyyy-MM-dd');

  static String formatIsoDate(DateTime dt) =>
      _isoDateFmt.format(DateTime(dt.year, dt.month, dt.day));

  static DateTime parseIsoDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String todayIso() => formatIsoDate(DateTime.now());

  static String yesterdayIso() =>
      formatIsoDate(DateTime.now().subtract(const Duration(days: 1)));

  /// 获取某日期所在自然周的周一（默认周一为每周第一天）
  static DateTime startOfWeek(DateTime date, {int weekStartsOn = DateTime.monday}) {
    final d = dateOnly(date);
    final diff = (d.weekday - weekStartsOn + 7) % 7;
    return d.subtract(Duration(days: diff));
  }

  static String startOfWeekIso(DateTime date, {int weekStartsOn = DateTime.monday}) =>
      formatIsoDate(startOfWeek(date, weekStartsOn: weekStartsOn));

  /// 返回某周从周一到周日的 7 个日期
  static List<DateTime> daysOfWeek(DateTime weekStart) {
    final start = dateOnly(weekStart);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// 计算指定日期处于学期的第几教学周（1-based；早于开学返回 0 或负数，晚于结课返回总周数+）
  static int teachingWeekIndex({
    required DateTime targetDate,
    required DateTime semesterStart,
    int weekStartsOn = DateTime.monday,
  }) {
    final firstWeekStart = startOfWeek(semesterStart, weekStartsOn: weekStartsOn);
    final targetWeekStart = startOfWeek(targetDate, weekStartsOn: weekStartsOn);
    final diffDays = targetWeekStart.difference(firstWeekStart).inDays;
    return (diffDays ~/ 7) + 1;
  }

  /// 计算学期总教学周数
  static int totalTeachingWeeks({
    required DateTime semesterStart,
    required DateTime semesterEnd,
    int weekStartsOn = DateTime.monday,
  }) {
    final index = teachingWeekIndex(
      targetDate: semesterEnd,
      semesterStart: semesterStart,
      weekStartsOn: weekStartsOn,
    );
    return index < 1 ? 1 : index;
  }

  /// 获取某年某月的总天数
  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// 中文星期简称
  static String weekdayShortCn(int weekday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${names[(weekday - 1) % 7]}';
  }
}
