import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/task_editor_dialog.dart';
import 'task_detail_panel.dart';

/// 日计划视图：今日待办、P0-P3 优先级、标签筛选、目标溯源、昨日未完成一键顺延、移动端左/右滑手势
class DailyPage extends ConsumerWidget {
  const DailyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final tasksAsync = ref.watch(dailyTasksStreamProvider);
    final overdueTasks = ref.watch(overdueTasksStreamProvider).valueOrNull ?? [];
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final allTags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final taskTagsMap = ref.watch(taskTagsMapProvider).valueOrNull ?? {};
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;

    final goalById = {for (final g in allGoals) g.id: g};
    final isToday = TermDateUtils.formatIsoDate(selectedDate) ==
        TermDateUtils.todayIso();

    String? weekHint;
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: selectedDate,
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) weekHint = '第 $w 教学周';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部日期切换与快速添加栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isToday
                            ? '今天'
                            : '${selectedDate.month}月${selectedDate.day}日',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedDate.month}/${selectedDate.day} ${TermDateUtils.weekdayShortCn(selectedDate.weekday)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                      if (weekHint != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            weekHint,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: '前一天',
                onPressed: () => ref.read(selectedDateProvider.notifier).state =
                    selectedDate.subtract(const Duration(days: 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              TextButton(
                onPressed: () => ref.read(selectedDateProvider.notifier).state =
                    TermDateUtils.dateOnly(DateTime.now()),
                child: const Text('今天'),
              ),
              IconButton(
                tooltip: '后一天',
                onPressed: () => ref.read(selectedDateProvider.notifier).state =
                    selectedDate.add(const Duration(days: 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (Responsive.isDesktop(context)) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => TaskEditorDialog.show(
                    context,
                    initialScheduledDate:
                        TermDateUtils.formatIsoDate(selectedDate),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建任务 (Ctrl+N)'),
                ),
              ],
            ],
          ),
        ),

        // 昨日/往期未完成顺延横幅
        if (isToday && overdueTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '昨日及往期还有 ${overdueTasks.length} 项未完成任务',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final moved = await ref
                          .read(taskRepositoryProvider)
                          .postponeOverdueToToday();
                      if (context.mounted && moved > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已将 $moved 项未完成计划顺延至今天')),
                        );
                      }
                    },
                    child: const Text('一键顺延至今天'),
                  ),
                ],
              ),
            ),
          ),

        // 标签筛选条（移动端直接展示，桌面端也可快速切换）
        if (allTags.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('全部'),
                    selected: selectedTagId == null,
                    onSelected: (_) =>
                        ref.read(selectedTagFilterProvider.notifier).state =
                            null,
                  ),
                ),
                ...allTags.map((tag) {
                  final color = AppTheme.parseHex(tag.colorHex);
                  final selected = selectedTagId == tag.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(tag.name),
                      selected: selected,
                      selectedColor: color.withAlpha(40),
                      onSelected: (_) => ref
                          .read(selectedTagFilterProvider.notifier)
                          .state = selected ? null : tag.id,
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 6),

        // 任务主列表
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (tasks) {
              final filtered = selectedTagId == null
                  ? tasks
                  : tasks.where((t) {
                      final tags = taskTagsMap[t.id] ?? [];
                      return tags.any((tg) => tg.id == selectedTagId);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 52,
                        color: Theme.of(context).hintColor.withAlpha(110),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '今天暂无待办计划',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Responsive.isDesktop(context)
                            ? '按 Ctrl+N 或点击右上角按钮添加今日任务'
                            : '点击右下角 + 添加今日任务',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    ],
                  ),
                );
              }

              final doneCount = filtered.where((t) => t.isCompleted).length;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '完成进度：$doneCount / ${filtered.length}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    );
                  }

                  final task = filtered[index - 1];
                  final tags = taskTagsMap[task.id] ?? [];
                  final linkedGoal =
                      task.goalId != null ? goalById[task.goalId] : null;
                  final isSelected = selectedTaskId == task.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Slidable(
                      key: ValueKey(task.id),
                      // Android / 触控右滑完成
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.25,
                        children: [
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .toggleComplete(task.id),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: task.isCompleted
                                ? Icons.undo_rounded
                                : Icons.check_rounded,
                            label: task.isCompleted ? '撤销' : '完成',
                          ),
                        ],
                      ),
                      // 左滑顺延 / 删除
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.48,
                        children: [
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .postponeTaskByOneDay(task.id),
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: Icons.next_plan_outlined,
                            label: '顺延',
                          ),
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .softDeleteTask(task.id),
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: Icons.delete_outline,
                            label: '删除',
                          ),
                        ],
                      ),
                      child: _TaskCard(
                        task: task,
                        tags: tags,
                        linkedGoal: linkedGoal,
                        isSelected: isSelected,
                        onToggle: () => ref
                            .read(taskRepositoryProvider)
                            .toggleComplete(task.id),
                        onTap: () {
                          ref.read(selectedTaskIdProvider.notifier).state =
                              task.id;
                          if (!Responsive.isDesktop(context)) {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.85,
                                child: TaskDetailPanel(
                                  taskId: task.id,
                                  onClose: () => Navigator.of(context).pop(),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.tags,
    required this.linkedGoal,
    required this.isSelected,
    required this.onToggle,
    required this.onTap,
  });

  final TaskRow task;
  final List<TagRow> tags;
  final GoalRow? linkedGoal;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priority = TaskPriority.fromInt(task.priority);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 极简圆形勾选框（按 P0-P3 着色）
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted ? priority.color : Colors.transparent,
                      border: Border.all(
                        color: priority.color,
                        width: 1.8,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
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
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted ? theme.hintColor : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priority.color.withAlpha(28),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priority.code,
                            style: TextStyle(
                              color: priority.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (linkedGoal != null)
                          _MetaPill(
                            icon: Icons.flag_outlined,
                            text:
                                '${GoalLevel.fromString(linkedGoal!.level).label}: ${linkedGoal!.title}',
                            color: AppTheme.parseHex(linkedGoal!.colorHex),
                          ),
                        if (task.estimatedMinutes != null)
                          _MetaPill(
                            icon: Icons.timer_outlined,
                            text: '${task.estimatedMinutes}m',
                            color: theme.hintColor,
                          ),
                        if (task.dueAt != null)
                          _MetaPill(
                            icon: Icons.alarm_outlined,
                            text:
                                '${task.dueAt!.toLocal().hour.toString().padLeft(2, '0')}:${task.dueAt!.toLocal().minute.toString().padLeft(2, '0')}',
                            color: Colors.redAccent,
                          ),
                        if (task.postponeCount > 0)
                          _MetaPill(
                            icon: Icons.fast_forward_rounded,
                            text: '顺延×${task.postponeCount}',
                            color: Colors.orange,
                          ),
                        ...tags.map(
                          (tg) => _MetaPill(
                            icon: Icons.tag_rounded,
                            text: tg.name,
                            color: AppTheme.parseHex(tg.colorHex),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
