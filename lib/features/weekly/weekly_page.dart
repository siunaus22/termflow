import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';
import '../../shared/widgets/task_editor_dialog.dart';

/// 周计划视图：教学周/自然周切换、周目标进度、本周待办池（一键分配到本周具体某天）、七日日程分布
class WeeklyPage extends ConsumerWidget {
  const WeeklyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final weekStartIso = TermDateUtils.formatIsoDate(weekStart);
    final weekDays = TermDateUtils.daysOfWeek(weekStart);
    final weekEnd = weekDays.last;

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        // 顶部周导航栏
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teachingWeek != null && teachingWeek >= 1
                        ? '第 $teachingWeek 教学周'
                        : '周计划',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${weekStart.month}月${weekStart.day}日 - ${weekEnd.month}月${weekEnd.day}日',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
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
              tooltip: '下一周',
              onPressed: () =>
                  ref.read(selectedWeekStartProvider.notifier).state =
                      weekStart.add(const Duration(days: 7)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 1. 本周目标区块（可拆解自月度/学期目标）
        Row(
          children: [
            Text(
              '本周目标 (${weeklyGoals.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.weekly,
                targetYear: weekStart.year,
                targetMonth: weekStart.month,
                targetWeekIndex:
                    (teachingWeek != null && teachingWeek >= 1) ? teachingWeek : null,
                weekStartDate: weekStartIso,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增周目标'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (weeklyGoals.isEmpty)
          const _EmptyHintCard(
            text: '还没有本周目标，点击右上角从月度/学期目标拆解本周重点',
          )
        else
          ...weeklyGoals.map((goal) {
            final color = AppTheme.parseHex(goal.colorHex);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => GoalEditorDialog.show(
                  context,
                  level: GoalLevel.weekly,
                  existing: goal,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: '拆解为本周待办',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => TaskEditorDialog.show(
                              context,
                              initialWeekStartDate: weekStartIso,
                              initialGoalId: goal.id,
                            ),
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                          ),
                        ],
                      ),
                      if (goal.description.isNotEmpty) ...[
                        Text(
                          goal.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
        const SizedBox(height: 20),

        // 2. 本周待办池（未分配到具体某天 -> 支持一键点击周一~周日分配）
        Row(
          children: [
            Text(
              '本周待分配任务 (${unassignedTasks.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => TaskEditorDialog.show(
                context,
                initialWeekStartDate: weekStartIso,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加周待办'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (unassignedTasks.isEmpty)
          const _EmptyHintCard(text: '所有周待办均已分配到具体日期')
        else
          ...unassignedTasks.map((task) {
            final p = TaskPriority.fromInt(task.priority);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 一键分配到本周周一 ~ 周日
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '分配到：',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                      ),
                      ...weekDays.map((day) {
                        final iso = TermDateUtils.formatIsoDate(day);
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          label: Text(
                            '${TermDateUtils.weekdayShortCn(day.weekday)} ${day.day}',
                            style: const TextStyle(fontSize: 11),
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
        const SizedBox(height: 20),

        // 3. 本周 7 天日程分布概览
        Text(
          '七日日程排布',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...weekDays.map((day) {
          final iso = TermDateUtils.formatIsoDate(day);
          final isToday = iso == TermDateUtils.todayIso();
          final dayTasks =
              weeklyTasks.where((t) => t.scheduledDate == iso).toList();
          final done = dayTasks.where((t) => t.isCompleted).length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: ListTile(
              dense: true,
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = day;
                ref.read(activeNavProvider.notifier).state = NavSection.daily;
              },
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainer,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : null,
                  ),
                ),
              ),
              title: Text(
                '${TermDateUtils.weekdayShortCn(day.weekday)} · ${day.month}月${day.day}日',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: dayTasks.isEmpty
                  ? Text(
                      '暂无排期任务',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    )
                  : Text(
                      dayTasks.take(3).map((t) => t.title).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
              trailing: dayTasks.isEmpty
                  ? const Icon(Icons.chevron_right_rounded, size: 18)
                  : Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '$done/${dayTasks.length}',
                        style: const TextStyle(fontSize: 11),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
