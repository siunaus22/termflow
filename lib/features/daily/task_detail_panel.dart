import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/gemini_components.dart';
import '../../shared/widgets/goal_progress_bar.dart';

/// Gemini 毛玻璃任务详情与四级目标溯源侧栏
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
    final tokens = GeminiTokens.of(context);

    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (task) {
        if (task == null || task.isDeleted) {
          return Center(
            child: Text(
              '选择一条任务查看详情与目标溯源',
              style: TextStyle(color: tokens.textSecondary),
            ),
          );
        }

        _syncTextControllers(task);
        final priority = TaskPriority.fromInt(task.priority);
        final currentTagIds =
            (taskTagsMap[task.id] ?? []).map((t) => t.id).toSet();
        final goalById = {for (final g in allGoals) g.id: g};
        final linkedGoal = task.goalId != null ? goalById[task.goalId] : null;

        final lineage = <GoalRow>[];
        GoalRow? cursor = linkedGoal;
        final visited = <String>{};
        while (cursor != null && visited.add(cursor.id)) {
          lineage.add(cursor);
          cursor =
              cursor.parentGoalId != null ? goalById[cursor.parentGoalId] : null;
        }
        final orderedLineage = lineage.reversed.toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  FilterChip(
                    selected: task.isCompleted,
                    selectedColor: GeminiTokens.mintSuccess.withAlpha(42),
                    checkmarkColor: GeminiTokens.mintSuccess,
                    label: Text(
                      task.isCompleted ? '已完成' : '标记完成',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    onSelected: (_) => ref
                        .read(taskRepositoryProvider)
                        .toggleComplete(task.id),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '顺延一天',
                    onPressed: () => ref
                        .read(taskRepositoryProvider)
                        .postponeTaskByOneDay(task.id),
                    icon: Icon(
                      Icons.next_plan_outlined,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
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
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: GeminiTokens.roseAccent,
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: tokens.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.glassBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
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
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '补充子步骤、关键思路或参考备注...',
                    ),
                    onChanged: (v) => ref
                        .read(taskRepositoryProvider)
                        .updateTask(id: task.id, notes: v),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '优先级',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TaskPriority.values.map((p) {
                      final selected = priority == p;
                      return ChoiceChip(
                        label: Text(p.code),
                        selected: selected,
                        selectedColor: p.color.withAlpha(46),
                        labelStyle: TextStyle(
                          color: selected
                              ? tokens.textPrimary
                              : tokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => ref
                            .read(taskRepositoryProvider)
                            .updateTask(id: task.id, priority: p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
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
                              await ref.read(taskRepositoryProvider).updateTask(
                                    id: task.id,
                                    scheduledDate:
                                        TermDateUtils.formatIsoDate(picked),
                                  );
                            }
                          },
                          icon: const Icon(Icons.today_rounded, size: 17),
                          label: Text(task.scheduledDate ?? '未排期'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 108,
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
                  const SizedBox(height: 18),
                  Text(
                    '四级目标溯源',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    onChanged: (v) =>
                        ref.read(taskRepositoryProvider).updateTask(
                              id: task.id,
                              goalId: v,
                              clearGoal: v == null,
                            ),
                  ),
                  if (orderedLineage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GeminiGlassCard(
                      enableBlur: false,
                      backgroundColor: tokens.glassPill,
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const GeminiSparkleIcon(size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '进度联动链路',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final g in orderedLineage) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${GoalLevel.fromString(g.level).label} · ${g.title}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  GoalProgressBar(
                                    progress: g.cachedProgress,
                                    color: AppTheme.parseHex(g.colorHex),
                                    height: 5.5,
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
                  Text(
                    '分类标签',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.map((tag) {
                      final selected = currentTagIds.contains(tag.id);
                      final color = AppTheme.parseHex(tag.colorHex);
                      return FilterChip(
                        avatar: CircleAvatar(radius: 4, backgroundColor: color),
                        label: Text(tag.name),
                        selected: selected,
                        selectedColor: color.withAlpha(46),
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
        );
      },
    );
  }
}

final _singleTaskProvider =
    StreamProvider.family<TaskRow?, String>((ref, taskId) {
  return ref.watch(taskRepositoryProvider).watchTaskById(taskId);
});
