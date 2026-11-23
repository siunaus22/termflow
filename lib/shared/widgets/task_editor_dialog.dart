import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../providers/app_providers.dart';

/// 快速新建任务弹窗（支持 Windows `Ctrl+N` 与 Android FAB 呼出）
class TaskEditorDialog extends ConsumerStatefulWidget {
  const TaskEditorDialog({
    super.key,
    this.initialScheduledDate,
    this.initialWeekStartDate,
    this.initialGoalId,
  });

  final String? initialScheduledDate;
  final String? initialWeekStartDate;
  final String? initialGoalId;

  static Future<void> show(
    BuildContext context, {
    String? initialScheduledDate,
    String? initialWeekStartDate,
    String? initialGoalId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TaskEditorDialog(
        initialScheduledDate: initialScheduledDate,
        initialWeekStartDate: initialWeekStartDate,
        initialGoalId: initialGoalId,
      ),
    );
  }

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _minutesController = TextEditingController();

  TaskPriority _priority = TaskPriority.p2;
  String? _scheduledDate;
  String? _goalId;
  DateTime? _dueAt;
  final Set<String> _selectedTagIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.initialScheduledDate;
    _goalId = widget.initialGoalId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledDate() async {
    final base = _scheduledDate != null
        ? TermDateUtils.parseIsoDate(_scheduledDate!)
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _scheduledDate = TermDateUtils.formatIsoDate(picked));
    }
  }

  Future<void> _pickDueTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt?.toLocal() ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt?.toLocal() ?? now),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final activeSem = ref.read(activeSemesterProvider).valueOrNull;
      final minutes = int.tryParse(_minutesController.text.trim());
      await ref.read(taskRepositoryProvider).createTask(
            title: title,
            notes: _notesController.text.trim(),
            priority: _priority,
            estimatedMinutes: minutes,
            scheduledDate: _scheduledDate,
            weekStartDate: _scheduledDate != null
                ? TermDateUtils.startOfWeekIso(
                    TermDateUtils.parseIsoDate(_scheduledDate!),
                  )
                : widget.initialWeekStartDate,
            dueAt: _dueAt,
            goalId: _goalId,
            semesterId: activeSem?.id,
            tagIds: _selectedTagIds.toList(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];

    return AlertDialog(
      title: const Text('新建计划任务'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '准备做什么？（例如：完成高数第三章习题）',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '备注 / 关键步骤（可选）',
                ),
              ),
              const SizedBox(height: 14),

              // 优先级选择 P0 - P3
              Text('优先级', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: TaskPriority.values.map((p) {
                  final selected = _priority == p;
                  return ChoiceChip(
                    label: Text('${p.code} ${p.label}'),
                    selected: selected,
                    selectedColor: p.color.withAlpha(45),
                    labelStyle: TextStyle(
                      color: selected ? p.color : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // 排期日期 + 预计耗时 + 截止时间
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickScheduledDate,
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        _scheduledDate ?? '周待办池（未指定日）',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '耗时(分)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDueTime,
                    icon: const Icon(Icons.alarm_outlined, size: 16),
                    label: Text(
                      _dueAt == null
                          ? '设置截止时间'
                          : '${_dueAt!.month}/${_dueAt!.day} ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      tooltip: '清除截止时间',
                      onPressed: () => setState(() => _dueAt = null),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 关联上级目标（周/月/学期目标溯源）
              Text('关联目标（完成后自动推进进度）',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: goals.any((g) => g.id == _goalId) ? _goalId : null,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('不关联目标'),
                  ),
                  ...goals.map(
                    (g) => DropdownMenuItem<String?>(
                      value: g.id,
                      child: Text(
                        '[${GoalLevel.fromString(g.level).label}] ${g.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _goalId = v),
              ),
              const SizedBox(height: 14),

              // 标签选择
              if (tags.isNotEmpty) ...[
                Text('标签分类', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    final color = AppTheme.parseHex(tag.colorHex);
                    final selected = _selectedTagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: selected,
                      selectedColor: color.withAlpha(45),
                      checkmarkColor: color,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedTagIds.add(tag.id);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建任务'),
        ),
      ],
    );
  }
}
