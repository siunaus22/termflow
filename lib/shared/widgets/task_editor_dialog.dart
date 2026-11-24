import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../providers/app_providers.dart';
import 'google_brand_widgets.dart';

/// Google Tasks / Material 3 风格快速新建任务弹窗
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
      title: const Row(
        children: [
          GooglePlusIcon(size: 22),
          SizedBox(width: 10),
          Text('新建计划事项', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GoogleFourColorBar(height: 3),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '准备完成什么？（例如：刷完图论最短路专题）',
                  prefixIcon: Icon(Icons.task_alt_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '添加关键步骤或备注（可选）',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // 优先级选择 P0 - P3（Google 四色映射）
              Text(
                '色彩优先级',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: TaskPriority.values.map((p) {
                  final selected = _priority == p;
                  return ChoiceChip(
                    label: Text('${p.code} · ${p.label}'),
                    selected: selected,
                    selectedColor: p.color.withAlpha(42),
                    side: BorderSide(
                      color: selected ? p.color : p.color.withAlpha(80),
                    ),
                    labelStyle: TextStyle(
                      color: p.color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 排期日期 + 预计耗时
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickScheduledDate,
                      icon: const Icon(Icons.today_rounded, size: 17),
                      label: Text(
                        _scheduledDate ?? '放入本周待办池',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 118,
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
                    icon: const Icon(Icons.alarm_rounded, size: 17),
                    label: Text(
                      _dueAt == null
                          ? '设置截止提醒时间'
                          : '${_dueAt!.month}/${_dueAt!.day} ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      tooltip: '清除截止时间',
                      onPressed: () => setState(() => _dueAt = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 关联上级目标
              Text(
                '关联上级目标（完成后自动推进进度）',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue:
                    goals.any((g) => g.id == _goalId) ? _goalId : null,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('暂不关联目标'),
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

              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '多彩标签',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    final color = AppTheme.parseHex(tag.colorHex);
                    final selected = _selectedTagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: selected,
                      selectedColor: color.withAlpha(42),
                      checkmarkColor: color,
                      side: BorderSide(
                        color: selected ? color : color.withAlpha(80),
                      ),
                      labelStyle: TextStyle(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
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
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('创建'),
        ),
      ],
    );
  }
}
