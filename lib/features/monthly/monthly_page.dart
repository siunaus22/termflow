import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';

/// 月计划视图：月历任务热力指示视图 + 月度里程碑目标拆解
class MonthlyPage extends ConsumerStatefulWidget {
  const MonthlyPage({super.key});

  @override
  ConsumerState<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends ConsumerState<MonthlyPage> {
  String? _focusedDayIso;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final monthlyGoals = ref.watch(monthlyGoalsStreamProvider).valueOrNull ?? [];
    final monthlyTasks = ref.watch(monthlyTasksStreamProvider).valueOrNull ?? [];
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final goalById = {for (final g in allGoals) g.id: g};

    final tasksByDay = <String, List<TaskRow>>{};
    for (final t in monthlyTasks) {
      if (t.scheduledDate != null) {
        tasksByDay.putIfAbsent(t.scheduledDate!, () => []).add(t);
      }
    }

    final focusedIso = _focusedDayIso ?? TermDateUtils.todayIso();
    final focusedTasks = tasksByDay[focusedIso] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        // 顶部月份切换栏
        Row(
          children: [
            Text(
              '${month.year}年 ${month.month}月',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              tooltip: '上个月',
              onPressed: () {
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1, 1);
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            TextButton(
              onPressed: () {
                final now = DateTime.now();
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(now.year, now.month, 1);
                setState(() => _focusedDayIso = TermDateUtils.todayIso());
              },
              child: const Text('本月'),
            ),
            IconButton(
              tooltip: '下个月',
              onPressed: () {
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1, 1);
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. 交互式月历网格
        _MonthlyCalendarGrid(
          year: month.year,
          month: month.month,
          tasksByDay: tasksByDay,
          focusedDayIso: focusedIso,
          onSelectDay: (iso) => setState(() => _focusedDayIso = iso),
          onJumpToDay: (date) {
            ref.read(selectedDateProvider.notifier).state = date;
            ref.read(activeNavProvider.notifier).state = NavSection.daily;
          },
        ),
        const SizedBox(height: 14),

        // 选中日期的任务快览
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$focusedIso 任务快览 (${focusedTasks.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(selectedDateProvider.notifier).state =
                          TermDateUtils.parseIsoDate(focusedIso);
                      ref.read(activeNavProvider.notifier).state =
                          NavSection.daily;
                    },
                    child: const Text('进入该日'),
                  ),
                ],
              ),
              if (focusedTasks.isEmpty)
                Text(
                  '该日期暂无排期任务',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                )
              else
                ...focusedTasks.map(
                  (t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          t.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: t.isCompleted
                              ? Colors.green
                              : TaskPriority.fromInt(t.priority).color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.title,
                            style: TextStyle(
                              decoration: t.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 2. 月度里程碑目标清单
        Row(
          children: [
            Text(
              '月度里程碑 (${monthlyGoals.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.monthly,
                targetYear: month.year,
                targetMonth: month.month,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增月度目标'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (monthlyGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              '还没有设置本月里程碑，建议将学期目标拆解为 2-4 个月度目标',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          )
        else
          ...monthlyGoals.map((goal) {
            final color = AppTheme.parseHex(goal.colorHex);
            final parent = goal.parentGoalId != null
                ? goalById[goal.parentGoalId]
                : null;
            final category = GoalCategory.fromString(goal.category);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => GoalEditorDialog.show(
                  context,
                  level: GoalLevel.monthly,
                  existing: goal,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: category.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.label,
                              style: TextStyle(
                                color: category.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              goal.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (parent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '归属学期目标：${parent.title}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      GoalProgressBar(
                        progress: goal.cachedProgress,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _MonthlyCalendarGrid extends StatelessWidget {
  const _MonthlyCalendarGrid({
    required this.year,
    required this.month,
    required this.tasksByDay,
    required this.focusedDayIso,
    required this.onSelectDay,
    required this.onJumpToDay,
  });

  final int year;
  final int month;
  final Map<String, List<TaskRow>> tasksByDay;
  final String focusedDayIso;
  final ValueChanged<String> onSelectDay;
  final ValueChanged<DateTime> onJumpToDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final leadingBlanks = (firstDay.weekday - DateTime.monday + 7) % 7;
    final totalDays = TermDateUtils.daysInMonth(year, month);
    final todayIso = TermDateUtils.todayIso();
    final cellCount = ((leadingBlanks + totalDays + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final dayNum = index - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > totalDays) {
                return const SizedBox.shrink();
              }
              final date = DateTime(year, month, dayNum);
              final iso = TermDateUtils.formatIsoDate(date);
              final dayTasks = tasksByDay[iso] ?? [];
              final isToday = iso == todayIso;
              final isFocused = iso == focusedDayIso;
              final hasUnfinished = dayTasks.any((t) => !t.isCompleted);

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelectDay(iso),
                onDoubleTap: () => onJumpToDay(date),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isFocused
                        ? Theme.of(context).colorScheme.primary.withAlpha(32)
                        : null,
                    border: isToday
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isFocused
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (dayTasks.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasUnfinished
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.green,
                              ),
                            ),
                            if (dayTasks.length > 1) ...[
                              const SizedBox(width: 2),
                              Text(
                                '${dayTasks.length}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
