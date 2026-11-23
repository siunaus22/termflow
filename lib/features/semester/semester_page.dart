import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_editor_dialog.dart';
import '../../shared/widgets/goal_progress_bar.dart';

/// 学期计划视图：学期周期配置、当前教学周自动计算、OKR 风格学期核心目标与进度可视化
class SemesterPage extends ConsumerWidget {
  const SemesterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semesters = ref.watch(semestersStreamProvider).valueOrNull ?? [];
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final semesterGoals =
        ref.watch(semesterGoalsStreamProvider).valueOrNull ?? [];
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        // 顶部标题与学期管理按钮
        Row(
          children: [
            Text(
              '学期计划',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
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

        // 1. 当前激活学期卡片（含教学周自动计算与时间进度条）
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                const Text('尚未创建学期，请先新建一个学期以启用教学周自动计算'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _showSemesterDialog(context, ref),
                  child: const Text('创建当前学期'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),

        // 2. 学期核心目标（OKR 风格）
        Row(
          children: [
            Text(
              '学期核心目标 OKR (${semesterGoals.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => GoalEditorDialog.show(
                context,
                level: GoalLevel.semester,
                defaultSemesterId: activeSemester?.id,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加学期目标'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (semesterGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              '设定 3-5 个学期核心目标（如学业目标、项目目标、竞赛目标），向下拆解为月度与周计划后会自动汇总进度。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          )
        else
          ...semesterGoals.map((goal) {
            final category = GoalCategory.fromString(goal.category);
            final color = AppTheme.parseHex(goal.colorHex);
            final childCount =
                allGoals.where((g) => g.parentGoalId == goal.id).length;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => GoalEditorDialog.show(
                  context,
                  level: GoalLevel.semester,
                  existing: goal,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: category.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${category.label}目标',
                              style: TextStyle(
                                color: category.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              goal.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (childCount > 0)
                            Text(
                              '$childCount 项子里程碑',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                        ],
                      ),
                      if (goal.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          goal.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      GoalProgressBar(
                        progress: goal.cachedProgress,
                        color: color,
                        height: 8,
                      ),
                    ],
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
                        icon: const Icon(Icons.play_arrow_outlined, size: 16),
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
                        icon: const Icon(Icons.stop_outlined, size: 16),
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
    final timeProgress = totalDays <= 0
        ? 0.0
        : (elapsedDays / totalDays).clamp(0.0, 1.0);

    final weekStatusText = currentWeek < 1
        ? '尚未开学（距离开学还有 ${start.difference(today).inDays} 天）'
        : currentWeek > totalWeeks
            ? '本学期已结束（共 $totalWeeks 教学周）'
            : '当前处于第 $currentWeek / $totalWeeks 教学周';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withAlpha(205),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: semester.id,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    iconEnabledColor: Colors.white,
                    selectedItemBuilder: (ctx) => allSemesters
                        .map(
                          (s) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: allSemesters
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != semester.id) onSwitch(v);
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: '编辑学期日期',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${semester.startDate} ~ ${semester.endDate}',
            style: TextStyle(
              color: Colors.white.withAlpha(210),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            weekStatusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: timeProgress,
              minHeight: 7,
              backgroundColor: Colors.white.withAlpha(65),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
