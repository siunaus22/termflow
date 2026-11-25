import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/gemini_components.dart';
import '../../shared/widgets/google_brand_widgets.dart';
import '../../shared/widgets/task_editor_dialog.dart';
import 'task_detail_panel.dart';

/// Google Gemini App 风格日计划视图
/// 包含克制蓝紫渐变欢迎语、聚焦联动 GLSL 极光的流光胶囊输入栏、24px 高斯模糊毛玻璃清单容器
class DailyPage extends ConsumerWidget {
  const DailyPage({super.key});

  String _welcomeTitle(String? emailPrefix) {
    final name = (emailPrefix != null && emailPrefix.trim().isNotEmpty)
        ? '，${emailPrefix.trim()}'
        : '';
    final h = DateTime.now().hour;
    if (h < 12) return '早安$name';
    if (h < 18) return '午安$name';
    return '晚上好$name';
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
    final authUser = ref.watch(supabaseManagerProvider).user;

    final tokens = GeminiTokens.of(context);
    final goalById = {for (final g in allGoals) g.id: g};
    final selectedDateIso = TermDateUtils.formatIsoDate(selectedDate);
    final isToday = selectedDateIso == TermDateUtils.todayIso();

    String weekPart = '';
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: selectedDate,
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) weekPart = ' · 第 $w 教学周';
    }

    final allDayTasks = tasksAsync.valueOrNull ?? [];
    final doneAll = allDayTasks.where((t) => t.isCompleted).length;
    final userPrefix = authUser?.email?.split('@').first;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
          children: [
            // 1. Gemini 标志性欢迎语主标题（全场唯一使用蓝紫渐变文字的视觉锚点）
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GeminiGradientText(
                    isToday
                        ? _welcomeTitle(userPrefix)
                        : '${selectedDate.month}月${selectedDate.day}日 计划清单',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.7,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isToday
                        ? '今天准备推进哪一项核心目标？ · ${selectedDate.month}月${selectedDate.day}日 ${TermDateUtils.weekdayShortCn(selectedDate.weekday)}$weekPart'
                        : '${TermDateUtils.weekdayShortCn(selectedDate.weekday)}$weekPart',
                    style: TextStyle(
                      fontSize: 15,
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Gemini 核心胶囊输入栏（聚焦时自动唤醒底层 GLSL 极光并聚拢光晕）
            GeminiPromptBar(
              hintText: '输入今日待办并按回车快速添加，或点 + 展开完整属性...',
              onFocusChanged: (focused) {
                ref.read(geminiFocusPointProvider.notifier).state =
                    const Offset(0.5, 0.28);
                ref.read(geminiFocusActiveProvider.notifier).state = focused;
              },
              onQuickSubmit: (title) async {
                final activeSem = ref.read(activeSemesterProvider).valueOrNull;
                await ref.read(taskRepositoryProvider).createTask(
                      title: title,
                      scheduledDate: selectedDateIso,
                      semesterId: activeSem?.id,
                      tagIds: selectedTagId != null ? [selectedTagId] : const [],
                    );
              },
              onOpenFullEditor: () async {
                ref.read(geminiFocusPointProvider.notifier).state =
                    const Offset(0.5, 0.50);
                ref.read(geminiFocusActiveProvider.notifier).state = true;
                try {
                  await TaskEditorDialog.show(
                    context,
                    initialScheduledDate: selectedDateIso,
                  );
                } finally {
                  ref.read(geminiFocusActiveProvider.notifier).state = false;
                }
              },
              trailingActions: [
                IconButton(
                  tooltip: '前一天',
                  onPressed: () => ref.read(selectedDateProvider.notifier).state =
                      selectedDate.subtract(const Duration(days: 1)),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: tokens.textSecondary,
                  ),
                ),
                IconButton(
                  tooltip: '后一天',
                  onPressed: () => ref.read(selectedDateProvider.notifier).state =
                      selectedDate.add(const Duration(days: 1)),
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. 毛玻璃建议动作双胶囊行
            Row(
              children: [
                Expanded(
                  child: GeminiGlassCard(
                    borderRadius: BorderRadius.circular(999),
                    blurSigma: 20,
                    backgroundColor: tokens.glassPill,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        ref.read(selectedDateProvider.notifier).state = picked;
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GeminiSparkleIcon(size: 17),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            allDayTasks.isEmpty
                                ? '选择排期日期'
                                : '今日进度 $doneAll / ${allDayTasks.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GeminiGlassCard(
                    borderRadius: BorderRadius.circular(999),
                    blurSigma: 20,
                    isHighlighted: overdueTasks.isNotEmpty && isToday,
                    backgroundColor: tokens.glassPill,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    onTap: () async {
                      if (overdueTasks.isNotEmpty && isToday) {
                        final moved = await ref
                            .read(taskRepositoryProvider)
                            .postponeOverdueToToday();
                        if (context.mounted && moved > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已将 $moved 项未完成计划顺延至今天')),
                          );
                        }
                      } else if (isToday) {
                        ref.read(activeNavProvider.notifier).state =
                            NavSection.semester;
                      } else {
                        ref.read(selectedDateProvider.notifier).state =
                            TermDateUtils.dateOnly(DateTime.now());
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          overdueTasks.isNotEmpty && isToday
                              ? Icons.history_toggle_off_rounded
                              : (isToday
                                  ? Icons.school_outlined
                                  : Icons.today_outlined),
                          size: 18,
                          color: overdueTasks.isNotEmpty && isToday
                              ? GeminiTokens.cyanAccent
                              : tokens.textSecondary,
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            overdueTasks.isNotEmpty && isToday
                                ? '顺延未完成 (${overdueTasks.length})'
                                : (isToday ? '查看学期目标' : '回到今天'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. 轻量化胶囊标签栏
            if (allTags.isNotEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
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
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar:
                              CircleAvatar(radius: 4.5, backgroundColor: color),
                          label: Text(tag.name),
                          selected: selected,
                          selectedColor: color.withAlpha(46),
                          onSelected: (_) => ref
                              .read(selectedTagFilterProvider.notifier)
                              .state = selected ? null : tag.id,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. 28px 高斯模糊毛玻璃任务主容器（保证背景极光柔和透出且正文 WCAG AA+ 高对比清晰可读）
            tasksAsync.when(
              loading: () => const Column(
                children: [
                  GeminiShimmerSkeleton(height: 76),
                  SizedBox(height: 10),
                  GeminiShimmerSkeleton(height: 76),
                ],
              ),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (tasks) {
                final filtered = selectedTagId == null
                    ? tasks
                    : tasks.where((t) {
                        final tags = taskTagsMap[t.id] ?? [];
                        return tags.any((tg) => tg.id == selectedTagId);
                      }).toList();

                return GeminiGlassCard(
                  borderRadius: BorderRadius.circular(28),
                  blurSigma: 24,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isToday ? '今日待办事项' : '当日排期事项',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => TaskEditorDialog.show(
                              context,
                              initialScheduledDate: selectedDateIso,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                '+ 详细添加',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Row(
                            children: [
                              M3ScallopBadge(
                                size: 48,
                                color: tokens.glassPill,
                                child: const GeminiSparkleIcon(
                                  size: 20,
                                  animate: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '当前列表清清爽爽',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '在上方星芒输入栏输入计划按回车，即可瞬间创建今日待办',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(filtered.length, (i) {
                          final task = filtered[i];
                          final tags = taskTagsMap[task.id] ?? [];
                          final linkedGoal = task.goalId != null
                              ? goalById[task.goalId]
                              : null;
                          final isSelected = selectedTaskId == task.id;
                          final isLast = i == filtered.length - 1;

                          return Column(
                            children: [
                              Slidable(
                                key: ValueKey(task.id),
                                startActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.25,
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) => ref
                                          .read(taskRepositoryProvider)
                                          .toggleComplete(task.id),
                                      backgroundColor: GeminiTokens.mintSuccess,
                                      foregroundColor: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      icon: task.isCompleted
                                          ? Icons.undo_rounded
                                          : Icons.check_rounded,
                                      label: task.isCompleted ? '撤销' : '完成',
                                    ),
                                  ],
                                ),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.46,
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) => ref
                                          .read(taskRepositoryProvider)
                                          .postponeTaskByOneDay(task.id),
                                      backgroundColor:
                                          GeminiTokens.cobaltViolet,
                                      foregroundColor: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      icon: Icons.next_plan_outlined,
                                      label: '顺延',
                                    ),
                                    SlidableAction(
                                      onPressed: (_) => ref
                                          .read(taskRepositoryProvider)
                                          .softDeleteTask(task.id),
                                      backgroundColor: GeminiTokens.roseAccent,
                                      foregroundColor: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      icon: Icons.delete_outline_rounded,
                                      label: '删除',
                                    ),
                                  ],
                                ),
                                child: _GeminiTaskRow(
                                  task: task,
                                  tags: tags,
                                  linkedGoal: linkedGoal,
                                  isSelected: isSelected,
                                  onToggle: () => ref
                                      .read(taskRepositoryProvider)
                                      .toggleComplete(task.id),
                                  onTap: () {
                                    ref
                                        .read(selectedTaskIdProvider.notifier)
                                        .state = task.id;
                                    if (!Responsive.isDesktop(context)) {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        showDragHandle: true,
                                        builder: (_) => BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 20, sigmaY: 20),
                                          child: SizedBox(
                                            height: MediaQuery.sizeOf(context)
                                                    .height *
                                                0.85,
                                            child: TaskDetailPanel(
                                              taskId: task.id,
                                              onClose: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  indent: 62,
                                  color: tokens.glassBorder,
                                ),
                            ],
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiTaskRow extends StatelessWidget {
  const _GeminiTaskRow({
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
    final tokens = GeminiTokens.of(context);
    final priority = TaskPriority.fromInt(task.priority);

    final parts = <String>[priority.code];
    if (tags.isNotEmpty) {
      parts.add(tags.map((t) => t.name).join(' / '));
    }
    if (task.estimatedMinutes != null) {
      parts.add('${task.estimatedMinutes} 分钟');
    }
    if (linkedGoal != null) {
      parts.add(linkedGoal!.title);
    } else if (task.notes.isNotEmpty) {
      parts.add(task.notes);
    }
    if (task.postponeCount > 0) {
      parts.add('顺延 ${task.postponeCount} 次');
    }

    final badgeColor = task.isCompleted
        ? GeminiTokens.mintSuccess.withAlpha(42)
        : priority.color.withAlpha(32);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: GeminiTokens.fastDuration,
        curve: GeminiTokens.springCurve,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: tokens.glassPill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.glassHighlightBorder),
              )
            : null,
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: M3ScallopBadge(
                size: 46,
                color: badgeColor,
                child: Icon(
                  task.isCompleted
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 21,
                  color: task.isCompleted
                      ? GeminiTokens.mintSuccess
                      : priority.color,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: task.isCompleted
                          ? tokens.textSecondary
                          : tokens.textPrimary,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (task.dueAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${task.dueAt!.toLocal().hour.toString().padLeft(2, '0')}:${task.dueAt!.toLocal().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: GeminiTokens.roseAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
