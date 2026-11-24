import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';
import '../../shared/widgets/google_brand_widgets.dart';

/// Google Classroom / Material You 风格多彩学期计划视图
class SemesterPage extends ConsumerWidget {
  const SemesterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semestersStreamProvider).valueOrNull ?? [];
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final semesterGoals =
        ref.watch(semesterGoalsStreamProvider).valueOrNull ?? [];
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
      children: [
        // 顶部标题与新建学期胶囊按钮
        Row(
          children: [
            const GoogleBrandLogo(size: 28),
            const SizedBox(width: 10),
            Text(
              '学期蓝图',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showSemesterDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新建学期'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Google Material You 旗舰学期卡片（带四色装饰条 + 大号教学周圆环）
        if (activeSemester != null)
          _ActiveSemesterHeroCard(
            semester: activeSemester,
            allSemesters: semesters,
            onSwitch: (id) =>
                ref.read(semesterRepositoryProvider).setActiveSemester(id),
            onEdit: () =>
                _showSemesterDialog(context, ref, existing: activeSemester),
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                const GoogleBrandLogo(size: 44),
                const SizedBox(height: 12),
                const Text('尚未创建学期，请先新建当前学期以开启教学周计算'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _showSemesterDialog(context, ref),
                  child: const Text('创建当前学期'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        // 2. 多彩 OKR 学期核心目标卡片（学业蓝 / 项目青 / 竞赛黄 / 生活绿）
        Row(
          children: [
            Text(
              '学期核心目标 OKR (${semesterGoals.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.semester,
                defaultSemesterId: activeSemester?.id,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加学期目标'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (semesterGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.googleBlue.withAlpha(30),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppTheme.googleBlue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '设定 3–5 个多彩学期目标（学业 / 项目 / 竞赛 / 生活），拆解为月度与周计划后会自动推进完成百分比！',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...semesterGoals.map((goal) {
            final category = GoalCategory.fromString(goal.category);
            final color = AppTheme.parseHex(goal.colorHex);
            final childCount =
                allGoals.where((g) => g.parentGoalId == goal.id).length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppTheme.tonalContainer(
                  context,
                  color,
                  lightAlpha: 24,
                  darkAlpha: 42,
                ),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => GoalEditorDialog.show(
                    context,
                    level: GoalLevel.semester,
                    existing: goal,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: color.withAlpha(42),
                              child:
                                  Icon(category.icon, size: 20, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(34),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${category.label} OKR',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    goal.title,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (childCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$childCount 项子目标',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (goal.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            goal.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        GoalProgressBar(
                          progress: goal.cachedProgress,
                          color: color,
                          height: 9,
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新建学期' : '编辑学期'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleFourColorBar(height: 3),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '学期名称',
                    hintText: '如：2026-2027 第一学期',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: Text(TermDateUtils.formatIsoDate(startDate)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('至'),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.stop_rounded, size: 17),
                        label: Text(TermDateUtils.formatIsoDate(endDate)),
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

class _ActiveSemesterHeroCard extends StatelessWidget {
  const _ActiveSemesterHeroCard({
    required this.semester,
    required this.allSemesters,
    required this.onSwitch,
    required this.onEdit,
  });

  final SemesterRow semester;
  final List<SemesterRow> allSemesters;
  final ValueChanged<String> onSwitch;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final start = TermDateUtils.parseIsoDate(semester.startDate);
    final end = TermDateUtils.parseIsoDate(semester.endDate);
    final today = TermDateUtils.dateOnly(DateTime.now());
    final theme = Theme.of(context);

    final currentWeek = TermDateUtils.teachingWeekIndex(
      targetDate: today,
      semesterStart: start,
      weekStartsOn: semester.weekStartsOn,
    );
    final totalWeeks = TermDateUtils.totalTeachingWeeks(
      semesterStart: start,
      semesterEnd: end,
      weekStartsOn: semester.weekStartsOn,
    );

    final totalDays = end.difference(start).inDays;
    final elapsedDays = today.difference(start).inDays;
    final timeProgress =
        totalDays <= 0 ? 0.0 : (elapsedDays / totalDays).clamp(0.0, 1.0);

    final weekStatusText = currentWeek < 1
        ? '距离开学还有 ${start.difference(today).inDays} 天'
        : currentWeek > totalWeeks
            ? '本学期已圆满结束（共 $totalWeeks 教学周）'
            : '第 $currentWeek / $totalWeeks 教学周';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.tonalContainer(
          context,
          const Color(0xFFE37400),
          lightAlpha: 26,
          darkAlpha: 44,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const GoogleFourColorBar(height: 5),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GoogleProgressRing(
                  progress: timeProgress,
                  size: 72,
                  strokeWidth: 7.5,
                  centerChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentWeek < 1
                            ? '待开学'
                            : 'W${currentWeek.clamp(1, totalWeeks)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${(timeProgress * 100).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: semester.id,
                                isDense: true,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                items: allSemesters
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null && v != semester.id) {
                                    onSwitch(v);
                                  }
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '编辑学期起止日期',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_calendar_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${semester.startDate}  →  ${semester.endDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          weekStatusText,
                          style: const TextStyle(
                            color: Color(0xFFE37400),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
