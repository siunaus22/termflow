import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/gemini_components.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';
import '../../shared/widgets/google_brand_widgets.dart';

/// Google Gemini App 毛玻璃风格月计划视图
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
    final tokens = GeminiTokens.of(context);

    final tasksByDay = <String, List<TaskRow>>{};
    for (final t in monthlyTasks) {
      if (t.scheduledDate != null) {
        tasksByDay.putIfAbsent(t.scheduledDate!, () => []).add(t);
      }
    }

    final focusedIso = _focusedDayIso ?? TermDateUtils.todayIso();
    final focusedTasks = tasksByDay[focusedIso] ?? [];

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
                        '${month.year}年 ${month.month}月',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${monthlyGoals.length} 个月度里程碑 · ${monthlyTasks.length} 项排期事项',
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
            const SizedBox(height: 18),

            // 毛玻璃月历网格
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
            const SizedBox(height: 16),

            // 选中日日程快览
            GeminiGlassCard(
              borderRadius: BorderRadius.circular(26),
              blurSigma: 24,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$focusedIso 日程快览',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          ref.read(selectedDateProvider.notifier).state =
                              TermDateUtils.parseIsoDate(focusedIso);
                          ref.read(activeNavProvider.notifier).state =
                              NavSection.daily;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Text(
                            '进入当日 →',
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
                  const SizedBox(height: 10),
                  if (focusedTasks.isEmpty)
                    Text(
                      '该日期暂无排期事项',
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textSecondary,
                      ),
                    )
                  else
                    ...focusedTasks.map((t) {
                      final p = TaskPriority.fromInt(t.priority);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 7.5,
                              height: 7.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.isCompleted
                                    ? GeminiTokens.mintSuccess
                                    : p.color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: t.isCompleted
                                      ? tokens.textSecondary
                                      : tokens.textPrimary,
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
            const SizedBox(height: 16),

            // 月度里程碑毛玻璃容器
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
                        '月度里程碑 (${monthlyGoals.length})',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => GoalEditorDialog.show(
                          context,
                          level: GoalLevel.monthly,
                          targetYear: month.year,
                          targetMonth: month.month,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GeminiSparkleIcon(size: 14),
                              const SizedBox(width: 5),
                              Text(
                                '新增月度目标',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (monthlyGoals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '暂未添加月度里程碑，建议将学期核心目标拆解为 2–4 个月度节点。',
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...List.generate(monthlyGoals.length, (i) {
                      final goal = monthlyGoals[i];
                      final color = AppTheme.parseHex(goal.colorHex);
                      final category = GoalCategory.fromString(goal.category);
                      final parent = goal.parentGoalId != null
                          ? goalById[goal.parentGoalId]
                          : null;

                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => GoalEditorDialog.show(
                              context,
                              level: GoalLevel.monthly,
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
                                        if (parent != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '源自：${parent.title}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        GoalProgressBar(
                                          progress: goal.cachedProgress,
                                          color: color,
                                          height: 5.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < monthlyGoals.length - 1)
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
          ],
        ),
      ),
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
    final tokens = GeminiTokens.of(context);

    return GeminiGlassCard(
      borderRadius: BorderRadius.circular(28),
      blurSigma: 24,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        children: [
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
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
              childAspectRatio: 1.05,
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
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelectDay(iso),
                onDoubleTap: () => onJumpToDay(date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: GeminiTokens.fastDuration,
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isToday ? tokens.brandGradient : null,
                        color: !isToday && isFocused ? tokens.glassPill : null,
                        border: !isToday && isFocused
                            ? Border.all(color: tokens.glassHighlightBorder)
                            : null,
                      ),
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isToday || isFocused
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isToday ? Colors.white : tokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (dayTasks.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dayTasks.take(3).map((t) {
                          final dotColor = t.isCompleted
                              ? GeminiTokens.mintSuccess
                              : TaskPriority.fromInt(t.priority).color;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          );
                        }).toList(),
                      )
                    else
                      const SizedBox(height: 4.5),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
