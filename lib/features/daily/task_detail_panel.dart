import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/goal_progress_bar.dart';

/// 任务详情与关联目标编辑面板（Windows 桌面端常驻右侧栏；Android 移动端底部弹层复用）
class TaskDetailPanel extends ConsumerStatefulWidget {
  const TaskDetailPanel({
    super.key,
    required this.taskId,
    this.onClose,
  });

  final String taskId;
  final VoidCallback? onClose;

  @override
  ConsumerState<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _minutesController = TextEditingController();
  String? _loadedTaskId;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _syncTextControllers(TaskRow task) {
    if (_loadedTaskId != task.id) {
      _loadedTaskId = task.id;
      _titleController.text = task.title;
      _notesController.text = task.notes;
      _minutesController.text = task.estimatedMinutes?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(_singleTaskProvider(widget.taskId));
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final allTags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final taskTagsMap = ref.watch(taskTagsMapProvider).valueOrNull ?? {};

    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (task) {
        if (task == null || task.isDeleted) {
          return Center(
            child: Text(
              '选择一条任务以查看详情与目标溯源',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          );
        }

        _syncTextControllers(task);
        final priority = TaskPriority.fromInt(task.priority);
        final currentTagIds =
            (taskTagsMap[task.id] ?? []).map((t) => t.id).toSet();
        final goalById = {for (final g in allGoals) g.id: g};
        final linkedGoal = task.goalId != null ? goalById[task.goalId] : null;

        // 构造目标溯源链（学期 -> 月 -> 周）
        final lineage = <GoalRow>[];
        GoalRow? cursor = linkedGoal;
        final visited = <String>{};
        while (cursor != null && visited.add(cursor.id)) {
          lineage.add(cursor);
          cursor =
              cursor.parentGoalId != null ? goalById[cursor.parentGoalId] : null;
        }
        final orderedLineage = lineage.reversed.toList();

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Column(
            children: [
              // 顶部操作栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      activeColor: priority.color,
                      shape: const CircleBorder(),
                      onChanged: (_) => ref
                          .read(taskRepositoryProvider)
                          .toggleComplete(task.id),
                    ),
                    Text(
                      task.isCompleted ? '已完成' : '进行中',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '顺延一天',
                      onPressed: () => ref
                          .read(taskRepositoryProvider)
                          .postponeTaskByOneDay(task.id),
                      icon: const Icon(Icons.next_plan_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: '删除任务',
                      onPressed: () async {
                        await ref
                            .read(taskRepositoryProvider)
                            .softDeleteTask(task.id);
                        ref.read(selectedTaskIdProvider.notifier).state = null;
                        widget.onClose?.call();
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 标题
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                      decoration: const InputDecoration(hintText: '任务标题'),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          ref
                              .read(taskRepositoryProvider)
                              .updateTask(id: task.id, title: v);
                        }
                      },
                      onEditingComplete: () {
                        final v = _titleController.text.trim();
                        if (v.isNotEmpty) {
                          ref
                              .read(taskRepositoryProvider)
                              .updateTask(id: task.id, title: v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // 备注
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: '添加备注或子步骤...'),
                      onChanged: (v) => ref
                          .read(taskRepositoryProvider)
                          .updateTask(id: task.id, notes: v),
                    ),
                    const SizedBox(height: 18),

                    // 优先级 P0-P3
                    Text('优先级', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: TaskPriority.values.map((p) {
                        final selected = priority == p;
                        return ChoiceChip(
                          label: Text(p.code),
                          selected: selected,
                          selectedColor: p.color.withAlpha(45),
                          labelStyle: TextStyle(
                            color: selected ? p.color : null,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => ref
                              .read(taskRepositoryProvider)
                              .updateTask(id: task.id, priority: p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 计划日期 & 预计耗时
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: task.scheduledDate != null
                                    ? TermDateUtils.parseIsoDate(
                                        task.scheduledDate!)
                                    : DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                await ref
                                    .read(taskRepositoryProvider)
                                    .updateTask(
                                      id: task.id,
                                      scheduledDate:
                                          TermDateUtils.formatIsoDate(picked),
                                    );
                              }
                            },
                            icon: const Icon(Icons.event_outlined, size: 16),
                            label: Text(task.scheduledDate ?? '未排期'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 105,
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '耗时(分)',
                              isDense: true,
                            ),
                            onSubmitted: (v) {
                              final mins = int.tryParse(v.trim());
                              ref.read(taskRepositoryProvider).updateTask(
                                    id: task.id,
                                    estimatedMinutes: mins,
                                    clearEstimatedMinutes: mins == null,
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (task.postponeCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '已顺延 ${task.postponeCount} 次（原计划：${task.originalDate ?? '-'}）',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                            ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // 目标溯源与关联目标选择
                    Text('关联目标（目标溯源）',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('goal_${task.id}_${task.goalId}'),
                      initialValue: allGoals.any((g) => g.id == task.goalId)
                          ? task.goalId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('未关联上级目标'),
                        ),
                        ...allGoals.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Text(
                              '[${GoalLevel.fromString(g.level).label}] ${g.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(taskRepositoryProvider)
                          .updateTask(
                            id: task.id,
                            goalId: v,
                            clearGoal: v == null,
                          ),
                    ),
                    if (orderedLineage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '目标溯源链路',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            for (final g in orderedLineage) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${GoalLevel.fromString(g.level).label} · ${g.title}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    GoalProgressBar(
                                      progress: g.cachedProgress,
                                      color: AppTheme.parseHex(g.colorHex),
                                      height: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // 标签分类
                    Text('标签', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allTags.map((tag) {
                        final selected = currentTagIds.contains(tag.id);
                        final color = AppTheme.parseHex(tag.colorHex);
                        return FilterChip(
                          label: Text(tag.name),
                          selected: selected,
                          selectedColor: color.withAlpha(45),
                          checkmarkColor: color,
                          onSelected: (v) {
                            final next = Set<String>.from(currentTagIds);
                            if (v) {
                              next.add(tag.id);
                            } else {
                              next.remove(tag.id);
                            }
                            ref
                                .read(tagRepositoryProvider)
                                .setTagsForTask(task.id, next.toList());
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final _singleTaskProvider =
    StreamProvider.family<TaskRow?, String>((ref, taskId) {
  return ref.watch(taskRepositoryProvider).watchTaskById(taskId);
});
