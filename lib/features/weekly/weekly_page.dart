import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/gemini_components.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';
import '../../shared/widgets/google_brand_widgets.dart';
import '../../shared/widgets/task_editor_dialog.dart';

/// Google Gemini App 毛玻璃风格周计划视图
class WeeklyPage extends ConsumerWidget {
  const WeeklyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final weekStartIso = TermDateUtils.formatIsoDate(weekStart);
    final weekDays = TermDateUtils.daysOfWeek(weekStart);
    final weekEnd = weekDays.last;
    final tokens = GeminiTokens.of(context);

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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GeminiGradientText(
                        teachingWeek != null && teachingWeek >= 1
                            ? '第 $teachingWeek 教学周'
                            : '本周计划',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weekStart.month}月${weekStart.day}日 — ${weekEnd.month}月${weekEnd.day}日 · 共 ${weeklyTasks.length} 项安排',
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GeminiGlassCard(
                  borderRadius: BorderRadius.circular(999),
                  blurSigma: 18,
                  backgroundColor: tokens.glassPill,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 双胶囊快捷操作
            Row(
              children: [
                Expanded(
                  child: GeminiGlassCard(
                    borderRadius: BorderRadius.circular(999),
                    blurSigma: 20,
                    backgroundColor: tokens.glassPill,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: () => GoalEditorDialog.show(
                      context,
                      level: GoalLevel.weekly,
                      targetYear: weekStart.year,
                      targetMonth: weekStart.month,
                      targetWeekIndex:
                          (teachingWeek != null && teachingWeek >= 1)
                              ? teachingWeek
                              : null,
                      weekStartDate: weekStartIso,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GeminiSparkleIcon(size: 17),
                        const SizedBox(width: 9),
                        Text(
                          '新增本周目标',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.textPrimary,
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
                    backgroundColor: tokens.glassPill,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: () => TaskEditorDialog.show(
                      context,
                      initialWeekStartDate: weekStartIso,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_task_rounded,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '添加周待办',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 28px 毛玻璃本周目标容器
            GeminiGlassCard(
              borderRadius: BorderRadius.circular(28),
              blurSigma: 24,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '本周核心目标',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${weeklyGoals.length} 项',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (weeklyGoals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '暂未设定本周目标，可将月度里程碑拆解至本周。',
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...List.generate(weeklyGoals.length, (i) {
                      final goal = weeklyGoals[i];
                      final category = GoalCategory.fromString(goal.category);
                      final color = AppTheme.parseHex(goal.colorHex);
                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => GoalEditorDialog.show(
                              context,
                              level: GoalLevel.weekly,
                              existing: goal,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  M3ScallopBadge(
                                    size: 46,
                                    color: color.withAlpha(36),
                                    child: Icon(
                                      category.icon,
                                      size: 21,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          goal.title,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w500,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GoalProgressBar(
                                          progress: goal.cachedProgress,
                                          color: color,
                                          height: 5.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '拆解为本周待办',
                                    onPressed: () => TaskEditorDialog.show(
                                      context,
                                      initialWeekStartDate: weekStartIso,
                                      initialGoalId: goal.id,
                                    ),
                                    icon: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < weeklyGoals.length - 1)
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
            ),

            if (unassignedTasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              GeminiGlassCard(
                borderRadius: BorderRadius.circular(28),
                blurSigma: 24,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '待分配到具体日期 (${unassignedTasks.length})',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...unassignedTasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: weekDays.map((day) {
                                final iso = TermDateUtils.formatIsoDate(day);
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    '${TermDateUtils.weekdayShortCn(day.weekday)} ${day.day}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => ref
                                      .read(taskRepositoryProvider)
                                      .assignTaskToDate(task.id, iso),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '七日日程一览',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            M3SegmentedColumn(
              children: weekDays.map((day) {
                final iso = TermDateUtils.formatIsoDate(day);
                final isToday = iso == TermDateUtils.todayIso();
                final dayTasks =
                    weeklyTasks.where((t) => t.scheduledDate == iso).toList();
                final done = dayTasks.where((t) => t.isCompleted).length;

                return InkWell(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = day;
                    ref.read(activeNavProvider.notifier).state =
                        NavSection.daily;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isToday ? tokens.brandGradient : null,
                            color: isToday ? null : tokens.glassPill,
                            border: Border.all(color: tokens.glassBorder),
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  isToday ? Colors.white : tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${TermDateUtils.weekdayShortCn(day.weekday)}${isToday ? " · 今天" : ""}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayTasks.isEmpty
                                    ? '暂无排期'
                                    : dayTasks
                                        .take(3)
                                        .map((t) => t.title)
                                        .join(' · '),
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
                        if (dayTasks.isNotEmpty)
                          Text(
                            '$done/${dayTasks.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
