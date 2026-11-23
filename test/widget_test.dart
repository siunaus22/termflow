import 'package:flutter_test/flutter_test.dart';
import 'package:termflow/core/utils/date_utils.dart';

void main() {
  test('TermDateUtils calculates teaching week index accurately', () {
    final semStart = DateTime(2026, 9, 1); // Tuesday of Week 1
    expect(
      TermDateUtils.teachingWeekIndex(
        targetDate: DateTime(2026, 9, 1),
        semesterStart: semStart,
      ),
      1,
    );
    expect(
      TermDateUtils.teachingWeekIndex(
        targetDate: DateTime(2026, 9, 7), // Next Monday -> Week 2
        semesterStart: semStart,
      ),
      2,
    );
    expect(
      TermDateUtils.totalTeachingWeeks(
        semesterStart: DateTime(2026, 9, 1),
        semesterEnd: DateTime(2027, 1, 20),
      ),
      21,
    );
  });
}
