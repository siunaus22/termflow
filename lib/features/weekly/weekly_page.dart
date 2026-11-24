import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';
import '../../shared/widgets/task_editor_dialog.dart';

/// Google Workspace / Calendar 风格多彩周计划视图
class WeeklyPage extends ConsumerWidget {
  const WeeklyPage({super.key});

  static const _weekdayColors = [
    Color(0xFF1A73E8), // 周一 Google Blue
    Color(0xFF12B5CB), // 周二 Google Teal
    Color(0xFF34A853), // 周三 Google Green
    Color(0xFFF9AB00), // 周四 Google Yellow
    Color(0xFFFA7B17), // 周五 Google Orange
    Color(0xFF9334E6), // 周六 Google Purple
    Color(0xFFEA4335), // 周日 Google Red
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final weekStartIso = TermDateUtils.formatIsoDate(weekStart);
    final weekDays = TermDateUtils.daysOfWeek(weekStart);
    final weekEnd = weekDays.last;
    final theme = Theme.of(context);

    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final weeklyGoals = ref.watch(weeklyGoalsStreamProvider).valueOrNull ?? [];
    final weeklyTasks = ref.watch(weeklyTasksStreamProvider).valueOrNull ?? [];

    int? teachingWeek;
    if (activeSemester != null) {
      teachingWeek = TermDateUtils.teachingWeekIndex(
        targetDate: weekStart,
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
    }

    final unassignedTasks =
        weeklyTasks.where((t) => t.scheduledDate == null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      children: [
        // 1. 多彩周计划横幅卡片（Google Purple 主调）
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.tonalContainer(
              context,
              AppTheme.googlePurple,
              lightAlpha: 26,
              darkAlpha: 44,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.googlePurple.withAlpha(42),
                child: const Icon(
                  Icons.view_week_rounded,
                  color: AppTheme.googlePurple,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teachingWeek != null && teachingWeek >= 1
                          ? '第 $teachingWeek 教学周'
                          : '本周冲刺计划',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${weekStart.month}月${weekStart.day}日 — ${weekEnd.month}月${weekEnd.day}日 · 共 ${weeklyTasks.length} 项任务',
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
                      tooltip: '上一周',
                      onPressed: () =>
                          ref.read(selectedWeekStartProvider.notifier).state =
                              weekStart.subtract(const Duration(days: 7)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(selectedWeekStartProvider.notifier).state =
                              TermDateUtils.startOfWeek(DateTime.now()),
                      child: const Text('本周'),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '下一周',
                      onPressed: () =>
                          ref.read(selectedWeekStartProvider.notifier).state =
                              weekStart.add(const Duration(days: 7)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. 本周目标区块
        Row(
          children: [
            Text(
              '本周核心目标 (${weeklyGoals.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.weekly,
                targetYear: weekStart.year,
                targetMonth: weekStart.month,
                targetWeekIndex: (teachingWeek != null && teachingWeek >= 1)
                    ? teachingWeek
                    : null,
                weekStartDate: weekStartIso,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新增周目标'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (weeklyGoals.isEmpty)
          const _EmptyHintCard(
            text: '点击右上角将月度或学期目标拆解为本周目标，完成后自动向上汇总进度',
          )
        else
          ...weeklyGoals.map((goal) {
            final category = GoalCategory.fromString(goal.category);
            final color = AppTheme.parseHex(goal.colorHex);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppTheme.tonalContainer(
                  context,
                  color,
                  lightAlpha: 22,
                  darkAlpha: 36,
                ),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => GoalEditorDialog.show(
                    context,
                    level: GoalLevel.weekly,
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
                            Expanded(
                              child: Text(
                                goal.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: color.withAlpha(35),
                                foregroundColor: color,
                              ),
                              onPressed: () => TaskEditorDialog.show(
                                context,
                                initialWeekStartDate: weekStartIso,
                                initialGoalId: goal.id,
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 16),
                              label: const Text('拆解待办'),
                            ),
                          ],
                        ),
                        if (goal.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            goal.description,
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
        const SizedBox(height: 22),

        // 3. 本周待分配任务池（多彩星期胶囊一键排期）
        Row(
          children: [
            Text(
              '本周待分配池 (${unassignedTasks.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => TaskEditorDialog.show(
                context,
                initialWeekStartDate: weekStartIso,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加周待办'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (unassignedTasks.isEmpty)
          const _EmptyHintCard(text: '棒极了！本周待办均已分配到具体日期')
        else
          ...unassignedTasks.map((task) {
            final p = TaskPriority.fromInt(task.priority);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.color.withAlpha(70)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.color.withAlpha(32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          p.code,
                          style: TextStyle(
                            color: p.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '一键排到：',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ...List.generate(weekDays.length, (i) {
                        final day = weekDays[i];
                        final dayColor = _weekdayColors[i % 7];
                        final iso = TermDateUtils.formatIsoDate(day);
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: dayColor.withAlpha(24),
                          side: BorderSide(color: dayColor.withAlpha(70)),
                          label: Text(
                            '${TermDateUtils.weekdayShortCn(day.weekday)} ${day.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: dayColor,
                            ),
                          ),
                          onPressed: () {
                            ref
                                .read(taskRepositoryProvider)
                                .assignTaskToDate(task.id, iso);
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 22),

        // 4. 七日多彩日程排布
        Text(
          '七日色彩排布',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(weekDays.length, (idx) {
          final day = weekDays[idx];
          final dayColor = _weekdayColors[idx % 7];
          final iso = TermDateUtils.formatIsoDate(day);
          final isToday = iso == TermDateUtils.todayIso();
          final dayTasks =
              weeklyTasks.where((t) => t.scheduledDate == iso).toList();
          final done = dayTasks.where((t) => t.isCompleted).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isToday
                  ? AppTheme.tonalContainer(
                      context,
                      dayColor,
                      lightAlpha: 26,
                      darkAlpha: 42,
                    )
                  : theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = day;
                  ref.read(activeNavProvider.notifier).state = NavSection.daily;
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isToday ? dayColor : dayColor.withAlpha(45),
                      width: isToday ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            isToday ? dayColor : dayColor.withAlpha(32),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isToday ? Colors.white : dayColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${TermDateUtils.weekdayShortCn(day.weekday)} · ${day.month}月${day.day}日',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: dayColor,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '今天',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayTasks.isEmpty
                                  ? '轻松留白，暂无排期'
                                  : dayTasks
                                      .take(3)
                                      .map((t) => t.title)
                                      .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dayTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dayColor.withAlpha(28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$done/${dayTasks.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: dayColor,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.hintColor,
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

class _EmptyHintCard extends StatelessWidget {
  const _EmptyHintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
    );
  }
}
