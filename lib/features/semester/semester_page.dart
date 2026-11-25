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

/// Google Gemini App 毛玻璃风格学期蓝图视图
class SemesterPage extends ConsumerWidget {
  const SemesterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semestersStreamProvider).valueOrNull ?? [];
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final semesterGoals =
        ref.watch(semesterGoalsStreamProvider).valueOrNull ?? [];
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final tokens = GeminiTokens.of(context);

    int currentWeek = 1;
    int totalWeeks = 20;
    double timeProgress = 0.0;
    if (activeSemester != null) {
      final start = TermDateUtils.parseIsoDate(activeSemester.startDate);
      final end = TermDateUtils.parseIsoDate(activeSemester.endDate);
      final today = TermDateUtils.dateOnly(DateTime.now());
      currentWeek = TermDateUtils.teachingWeekIndex(
        targetDate: today,
        semesterStart: start,
        weekStartsOn: activeSemester.weekStartsOn,
      );
      totalWeeks = TermDateUtils.totalTeachingWeeks(
        semesterStart: start,
        semesterEnd: end,
        weekStartsOn: activeSemester.weekStartsOn,
      );
      final totalDays = end.difference(start).inDays;
      final elapsed = today.difference(start).inDays;
      timeProgress =
          totalDays <= 0 ? 0.0 : (elapsed / totalDays).clamp(0.0, 1.0);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
          children: [
            // 1. 学期概览毛玻璃英雄卡片
            GeminiGlassCard(
              borderRadius: BorderRadius.circular(28),
              blurSigma: 24,
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  GoogleProgressRing(
                    progress: timeProgress,
                    size: 78,
                    strokeWidth: 5.5,
                    centerChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeSemester == null
                              ? '--'
                              : 'W${currentWeek.clamp(1, totalWeeks)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          '共$totalWeeks周',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GeminiGradientText(
                          activeSemester?.name ?? '尚未创建学期',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          activeSemester == null
                              ? '创建学期周期后自动计算当前教学周'
                              : '${activeSemester.startDate}  →  ${activeSemester.endDate}',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showSemesterDialog(
                                context,
                                ref,
                                existing: activeSemester,
                              ),
                              icon: const Icon(Icons.edit_calendar_outlined,
                                  size: 16),
                              label: Text(
                                activeSemester == null ? '新建学期' : '编辑周期',
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showSemesterDialog(context, ref),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('新增学期'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (semesters.length > 1) ...[
              const SizedBox(height: 12),
              GeminiGlassCard(
                borderRadius: BorderRadius.circular(999),
                blurSigma: 20,
                backgroundColor: tokens.glassPill,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        size: 18, color: tokens.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeSemester?.id ?? semesters.first.id,
                          isExpanded: true,
                          items: semesters
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ref
                                  .read(semesterRepositoryProvider)
                                  .setActiveSemester(v);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // 2. 28px 毛玻璃核心目标 OKR 容器
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
                        '本学期核心目标 OKR (${semesterGoals.length})',
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
                          level: GoalLevel.semester,
                          defaultSemesterId: activeSemester?.id,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GeminiSparkleIcon(size: 15),
                              const SizedBox(width: 6),
                              Text(
                                '添加学期目标',
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
                  if (semesterGoals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Row(
                        children: [
                          M3ScallopBadge(
                            size: 48,
                            color: tokens.glassPill,
                            child: const GeminiSparkleIcon(size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '设定本学期的北极星目标',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '向下拆解为月度里程碑、周目标与日待办后，完成百分比将自动汇总推进',
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
                    ...List.generate(semesterGoals.length, (i) {
                      final goal = semesterGoals[i];
                      final category = GoalCategory.fromString(goal.category);
                      final color = AppTheme.parseHex(goal.colorHex);
                      final childCount = allGoals
                          .where((g) => g.parentGoalId == goal.id)
                          .length;

                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => GoalEditorDialog.show(
                              context,
                              level: GoalLevel.semester,
                              existing: goal,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          goal.description.isNotEmpty
                                              ? '${category.label} · ${goal.description}'
                                              : '${category.label}目标 · 已拆解 $childCount 项下级目标',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        GoalProgressBar(
                                          progress: goal.cachedProgress,
                                          color: color,
                                          height: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < semesterGoals.length - 1)
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

  Future<void> _showSemesterDialog(
    BuildContext context,
    WidgetRef ref, {
    SemesterRow? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '2026-2027 第一学期',
    );
    var startDate = existing != null
        ? TermDateUtils.parseIsoDate(existing.startDate)
        : DateTime(DateTime.now().year, 9, 1);
    var endDate = existing != null
        ? TermDateUtils.parseIsoDate(existing.endDate)
        : startDate.add(const Duration(days: 140));

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(132),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新建学期' : '编辑学期周期'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '学期名称',
                    hintText: '如：2026-2027 第一学期',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked;
                              if (endDate.isBefore(startDate)) {
                                endDate =
                                    startDate.add(const Duration(days: 120));
                              }
                            });
                          }
                        },
                        child: Text(TermDateUtils.formatIsoDate(startDate)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('至'),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        child: Text(TermDateUtils.formatIsoDate(endDate)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: GeminiTokens.cobaltViolet,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final repo = ref.read(semesterRepositoryProvider);
                if (existing == null) {
                  await repo.createSemester(
                    name: name,
                    startDate: TermDateUtils.formatIsoDate(startDate),
                    endDate: TermDateUtils.formatIsoDate(endDate),
                  );
                } else {
                  await repo.updateSemester(
                    id: existing.id,
                    name: name,
                    startDate: TermDateUtils.formatIsoDate(startDate),
                    endDate: TermDateUtils.formatIsoDate(endDate),
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }
}
