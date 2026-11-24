import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';

/// Google Calendar 风格多彩月计划视图
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
    final theme = Theme.of(context);

    final tasksByDay = <String, List<TaskRow>>{};
    for (final t in monthlyTasks) {
      if (t.scheduledDate != null) {
        tasksByDay.putIfAbsent(t.scheduledDate!, () => []).add(t);
      }
    }

    final focusedIso = _focusedDayIso ?? TermDateUtils.todayIso();
    final focusedTasks = tasksByDay[focusedIso] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      children: [
        // 1. 多彩月度横幅（Google Green 主题色）
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.tonalContainer(
              context,
              AppTheme.googleGreen,
              lightAlpha: 26,
              darkAlpha: 44,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.googleGreen.withAlpha(42),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF1E8E3E),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${month.year}年 ${month.month}月',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${monthlyGoals.length} 个月度里程碑 · ${monthlyTasks.length} 项日程安排',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
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
                        setState(
                            () => _focusedDayIso = TermDateUtils.todayIso());
                      },
                      child: const Text('本月'),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '下个月',
                      onPressed: () {
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(month.year, month.month + 1, 1);
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Google Calendar 风格多彩圆点月历网格
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

        // 选中日期快览胶囊卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$focusedIso 日程快览 (${focusedTasks.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
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
              const SizedBox(height: 8),
              if (focusedTasks.isEmpty)
                Text(
                  '该日期暂无排期事项',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                )
              else
                ...focusedTasks.map((t) {
                  final p = TaskPriority.fromInt(t.priority);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          t.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.circle,
                          size: t.isCompleted ? 16 : 10,
                          color:
                              t.isCompleted ? AppTheme.googleGreen : p.color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              decoration: t.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 3. 多彩月度里程碑目标清单
        Row(
          children: [
            Text(
              '月度里程碑 (${monthlyGoals.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.monthly,
                targetYear: month.year,
                targetMonth: month.month,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新增月度目标'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (monthlyGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text(
              '将学期大目标拆解为 2–4 个月度里程碑，节奏更清晰！',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppTheme.tonalContainer(
                  context,
                  color,
                  lightAlpha: 22,
                  darkAlpha: 38,
                ),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => GoalEditorDialog.show(
                    context,
                    level: GoalLevel.monthly,
                    existing: goal,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withAlpha(38),
                              child: Icon(category.icon, size: 17, color: color),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withAlpha(32),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category.label,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                goal.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (parent != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '源自学期目标：${parent.title}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GoalProgressBar(
                          progress: goal.cachedProgress,
                          color: color,
                        ),
                      ],
                    ),
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.08,
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

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelectDay(iso),
                onDoubleTap: () => onJumpToDay(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isToday
                        ? AppTheme.googleBlue.withAlpha(32)
                        : isFocused
                            ? theme.colorScheme.primary.withAlpha(22)
                            : null,
                    border: isFocused
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.8,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: isToday
                            ? BoxDecoration(
                                color: AppTheme.googleBlue,
                                borderRadius: BorderRadius.circular(999),
                              )
                            : null,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isFocused
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isToday ? Colors.white : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 多彩任务指示圆点（按任务优先级/完成态呈献 Google 四色圆点）
                      if (dayTasks.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayTasks.take(4).map((t) {
                            final dotColor = t.isCompleted
                                ? AppTheme.googleGreen
                                : TaskPriority.fromInt(t.priority).color;
                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 5.5,
                              height: 5.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            );
                          }).toList(),
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
