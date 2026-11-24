import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/google_brand_widgets.dart';
import 'task_detail_panel.dart';

/// Google Tasks / Google Fit 风格多彩日计划视图
class DailyPage extends ConsumerWidget {
  const DailyPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '早安，开启高效一天';
    if (h < 18) return '午后好，保持专注节奏';
    return '晚上好，复盘今日收获';
  }

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
    final theme = Theme.of(context);

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

    final allDayTasks = tasksAsync.valueOrNull ?? [];
    final doneAll = allDayTasks.where((t) => t.isCompleted).length;
    final pendingAll = allDayTasks.length - doneAll;
    final totalMinutes = allDayTasks
        .where((t) => !t.isCompleted)
        .fold<int>(0, (sum, t) => sum + (t.estimatedMinutes ?? 0));
    final dayProgress =
        allDayTasks.isEmpty ? 0.0 : doneAll / allDayTasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Google Material You 多彩日概览横幅（带 Google 四色圆环 + 胶囊指标）
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.tonalContainer(
                context,
                theme.colorScheme.primary,
                lightAlpha: 24,
                darkAlpha: 42,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GoogleProgressRing(
                      progress: dayProgress,
                      size: 62,
                      strokeWidth: 6.5,
                      centerChild: Text(
                        allDayTasks.isEmpty
                            ? '0%'
                            : '${(dayProgress * 100).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isToday)
                            Text(
                              _greeting(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                isToday
                                    ? '今天 · ${selectedDate.month}月${selectedDate.day}日'
                                    : '${selectedDate.month}月${selectedDate.day}日',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                TermDateUtils.weekdayShortCn(
                                    selectedDate.weekday),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (weekHint != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.googlePurple.withAlpha(32),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    weekHint,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.googlePurple,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _StatBadge(
                                icon: Icons.check_circle_rounded,
                                label: '已完成 $doneAll',
                                color: AppTheme.googleGreen,
                              ),
                              _StatBadge(
                                icon: Icons.pending_actions_rounded,
                                label: '待办 $pendingAll',
                                color: AppTheme.googleBlue,
                              ),
                              if (totalMinutes > 0)
                                _StatBadge(
                                  icon: Icons.bolt_rounded,
                                  label: '预计 $totalMinutes 分钟',
                                  color: const Color(0xFFE37400),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 胶囊日期切换器
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
                            tooltip: '前一天',
                            onPressed: () =>
                                ref.read(selectedDateProvider.notifier).state =
                                    selectedDate.subtract(
                                        const Duration(days: 1)),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          if (!isToday)
                            TextButton(
                              onPressed: () => ref
                                  .read(selectedDateProvider.notifier)
                                  .state = TermDateUtils.dateOnly(
                                DateTime.now(),
                              ),
                              child: const Text('今天'),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: '后一天',
                            onPressed: () =>
                                ref.read(selectedDateProvider.notifier).state =
                                    selectedDate.add(const Duration(days: 1)),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. Google Assistant 智能建议风格：往期未完成一键顺延卡片
        if (isToday && overdueTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.tonalContainer(
                  context,
                  AppTheme.googleYellow,
                  lightAlpha: 38,
                  darkAlpha: 48,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.googleYellow.withAlpha(55),
                    child: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: Color(0xFFB06000),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '有 ${overdueTasks.length} 项昨日及往期计划尚未完成',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.googleYellow.withAlpha(65),
                    ),
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
                    child: const Text(
                      '顺延至今天',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. 多彩胶囊标签筛选栏
        if (allTags.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('全部'),
                    selected: selectedTagId == null,
                    selectedColor: theme.colorScheme.primary.withAlpha(36),
                    labelStyle: TextStyle(
                      fontWeight: selectedTagId == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selectedTagId == null
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    onSelected: (_) =>
                        ref.read(selectedTagFilterProvider.notifier).state =
                            null,
                  ),
                ),
                ...allTags.map((tag) {
                  final color = AppTheme.parseHex(tag.colorHex);
                  final selected = selectedTagId == tag.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: CircleAvatar(radius: 5, backgroundColor: color),
                      label: Text(tag.name),
                      selected: selected,
                      selectedColor: color.withAlpha(42),
                      side: BorderSide(
                        color: selected ? color : color.withAlpha(70),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? color : null,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => ref
                          .read(selectedTagFilterProvider.notifier)
                          .state = selected ? null : tag.id,
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // 4. Google Keep / Tasks 风格多彩任务列表
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
                      const GoogleBrandLogo(size: 52),
                      const SizedBox(height: 16),
                      Text(
                        '清清爽爽，今日暂无待办',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Responsive.isDesktop(context)
                            ? '点击左上角彩色「+ 新建任务」或按 Ctrl+N 开启计划'
                            : '点击右下角彩色「+ 新建」按钮添加今日计划',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final task = filtered[index];
                  final tags = taskTagsMap[task.id] ?? [];
                  final linkedGoal =
                      task.goalId != null ? goalById[task.goalId] : null;
                  final isSelected = selectedTaskId == task.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Slidable(
                      key: ValueKey(task.id),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.26,
                        children: [
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .toggleComplete(task.id),
                            backgroundColor: AppTheme.googleGreen,
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            icon: task.isCompleted
                                ? Icons.undo_rounded
                                : Icons.check_rounded,
                            label: task.isCompleted ? '撤销' : '完成',
                          ),
                        ],
                      ),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.48,
                        children: [
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .postponeTaskByOneDay(task.id),
                            backgroundColor: const Color(0xFFF9AB00),
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            icon: Icons.next_plan_rounded,
                            label: '顺延',
                          ),
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(taskRepositoryProvider)
                                .softDeleteTask(task.id),
                            backgroundColor: AppTheme.googleRed,
                            foregroundColor: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            icon: Icons.delete_outline_rounded,
                            label: '删除',
                          ),
                        ],
                      ),
                      child: _GoogleTaskCard(
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
                              showDragHandle: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28)),
                              ),
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

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleTaskCard extends StatelessWidget {
  const _GoogleTaskCard({
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
    final cardAccent = linkedGoal != null
        ? AppTheme.parseHex(linkedGoal!.colorHex)
        : priority.color;

    final cardBg = task.isCompleted
        ? theme.colorScheme.surfaceContainerLowest.withAlpha(180)
        : AppTheme.tonalContainer(
            context,
            cardAccent,
            lightAlpha: 16,
            darkAlpha: 28,
          );

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? cardAccent
                  : cardAccent.withAlpha(task.isCompleted ? 25 : 55),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 彩色圆环完成按钮
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted
                          ? AppTheme.googleGreen
                          : priority.color.withAlpha(24),
                      border: Border.all(
                        color: task.isCompleted
                            ? AppTheme.googleGreen
                            : priority.color,
                        width: 2.2,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 13),
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
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted ? theme.hintColor : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: priority.color.withAlpha(32),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            priority.code,
                            style: TextStyle(
                              color: priority.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.notes.isNotEmpty && !task.isCompleted) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (linkedGoal != null)
                          _ColorfulPill(
                            icon: Icons.flag_rounded,
                            text:
                                '${GoalLevel.fromString(linkedGoal!.level).label} · ${linkedGoal!.title}',
                            color: AppTheme.parseHex(linkedGoal!.colorHex),
                          ),
                        if (task.estimatedMinutes != null)
                          _ColorfulPill(
                            icon: Icons.schedule_rounded,
                            text: '${task.estimatedMinutes} 分钟',
                            color: AppTheme.googleTeal,
                          ),
                        if (task.dueAt != null)
                          _ColorfulPill(
                            icon: Icons.notifications_active_rounded,
                            text:
                                '${task.dueAt!.toLocal().hour.toString().padLeft(2, '0')}:${task.dueAt!.toLocal().minute.toString().padLeft(2, '0')}',
                            color: AppTheme.googleRed,
                          ),
                        if (task.postponeCount > 0)
                          _ColorfulPill(
                            icon: Icons.fast_forward_rounded,
                            text: '顺延 ×${task.postponeCount}',
                            color: const Color(0xFFE37400),
                          ),
                        ...tags.map(
                          (tg) => _ColorfulPill(
                            icon: Icons.label_rounded,
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

class _ColorfulPill extends StatelessWidget {
  const _ColorfulPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
