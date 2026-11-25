import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../providers/app_providers.dart';
import 'gemini_components.dart';

/// Gemini 高对比胶囊新建任务弹窗
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
      barrierColor: Colors.black.withAlpha(132),
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
    final tokens = GeminiTokens.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          GeminiSparkleIcon(size: 21),
          SizedBox(width: 10),
          Text('新建计划事项'),
        ],
      ),
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
                  hintText: '输入待办事项标题...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '补充关键步骤或备注（可选）',
                ),
              ),
              const SizedBox(height: 16),
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
                spacing: 8,
                runSpacing: 6,
                children: TaskPriority.values.map((p) {
                  final selected = _priority == p;
                  return ChoiceChip(
                    label: Text('${p.code} · ${p.label}'),
                    selected: selected,
                    selectedColor: p.color.withAlpha(46),
                    labelStyle: TextStyle(
                      color: selected ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
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
              Text(
                '关联上级目标',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
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
                  '分类标签',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    final color = AppTheme.parseHex(tag.colorHex);
                    final selected = _selectedTagIds.contains(tag.id);
                    return FilterChip(
                      avatar: CircleAvatar(radius: 4.5, backgroundColor: color),
                      label: Text(tag.name),
                      selected: selected,
                      selectedColor: color.withAlpha(46),
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
          style: FilledButton.styleFrom(
            backgroundColor: GeminiTokens.cobaltViolet,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? '创建中...' : '创建事项'),
        ),
      ],
    );
  }
}
