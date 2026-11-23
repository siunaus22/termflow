import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../data/local/app_database.dart';
import '../providers/app_providers.dart';

/// 新建 / 编辑 学期 / 月度 / 周目标弹窗
class GoalEditorDialog extends ConsumerStatefulWidget {
  const GoalEditorDialog({
    super.key,
    required this.level,
    this.existing,
    this.defaultSemesterId,
    this.defaultParentGoalId,
    this.targetYear,
    this.targetMonth,
    this.targetWeekIndex,
    this.weekStartDate,
  });

  final GoalLevel level;
  final GoalRow? existing;
  final String? defaultSemesterId;
  final String? defaultParentGoalId;
  final int? targetYear;
  final int? targetMonth;
  final int? targetWeekIndex;
  final String? weekStartDate;

  static Future<void> show(
    BuildContext context, {
    required GoalLevel level,
    GoalRow? existing,
    String? defaultSemesterId,
    String? defaultParentGoalId,
    int? targetYear,
    int? targetMonth,
    int? targetWeekIndex,
    String? weekStartDate,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => GoalEditorDialog(
        level: level,
        existing: existing,
        defaultSemesterId: defaultSemesterId,
        defaultParentGoalId: defaultParentGoalId,
        targetYear: targetYear,
        targetMonth: targetMonth,
        targetWeekIndex: targetWeekIndex,
        weekStartDate: weekStartDate,
      ),
    );
  }

  @override
  ConsumerState<GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends ConsumerState<GoalEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late GoalCategory _category;
  String? _parentGoalId;
  late String _progressMode;
  late double _manualProgress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _category =
        e != null ? GoalCategory.fromString(e.category) : GoalCategory.academic;
    _parentGoalId = e?.parentGoalId ?? widget.defaultParentGoalId;
    _progressMode = e?.progressMode ?? 'auto';
    _manualProgress = e?.manualProgress ?? 0.0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      if (widget.existing == null) {
        await repo.createGoal(
          level: widget.level,
          title: title,
          description: _descController.text.trim(),
          category: _category,
          semesterId: widget.defaultSemesterId ??
              ref.read(activeSemesterProvider).valueOrNull?.id,
          parentGoalId: _parentGoalId,
          targetYear: widget.targetYear,
          targetMonth: widget.targetMonth,
          targetWeekIndex: widget.targetWeekIndex,
          weekStartDate: widget.weekStartDate,
          progressMode: _progressMode,
          manualProgress: _manualProgress,
        );
      } else {
        await repo.updateGoal(
          id: widget.existing!.id,
          title: title,
          description: _descController.text.trim(),
          category: _category,
          parentGoalId: _parentGoalId,
          clearParentGoal: _parentGoalId == null,
          progressMode: _progressMode,
          manualProgress: _manualProgress,
          colorHex: _category.colorHex,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGoals = ref.watch(allGoalsStreamProvider).valueOrNull ?? [];
    final allowedParentLevels = switch (widget.level) {
      GoalLevel.semester => <String>{},
      GoalLevel.monthly => {GoalLevel.semester.value},
      GoalLevel.weekly => {GoalLevel.monthly.value, GoalLevel.semester.value},
    };
    final parentCandidates = allGoals
        .where(
          (g) =>
              g.id != widget.existing?.id &&
              allowedParentLevels.contains(g.level),
        )
        .toList();

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? '新建${widget.level.label}'
            : '编辑${widget.level.label}',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: switch (widget.level) {
                    GoalLevel.semester => '例如：GPA 保持 3.9+ / 完成毕业设计原型',
                    GoalLevel.monthly => '例如：11月完成算法刷题 60 道',
                    GoalLevel.weekly => '例如：本周完成数据结构树与图专题',
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'OKR 关键结果 / 验收标准（可选）',
                ),
              ),
              const SizedBox(height: 14),
              Text('目标类别', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: GoalCategory.values.map((c) {
                  final selected = _category == c;
                  return ChoiceChip(
                    label: Text(c.label),
                    selected: selected,
                    selectedColor: c.color.withAlpha(45),
                    labelStyle: TextStyle(
                      color: selected ? c.color : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              if (allowedParentLevels.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('关联上级目标', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: parentCandidates.any((g) => g.id == _parentGoalId)
                      ? _parentGoalId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('暂不关联上级目标'),
                    ),
                    ...parentCandidates.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(
                          '[${GoalLevel.fromString(g.level).label}] ${g.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _parentGoalId = v),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('进度计算方式', style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'auto', label: Text('自动联动')),
                      ButtonSegment(value: 'manual', label: Text('手动进度')),
                    ],
                    selected: {_progressMode},
                    onSelectionChanged: (s) =>
                        setState(() => _progressMode = s.first),
                  ),
                ],
              ),
              if (_progressMode == 'manual') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _manualProgress,
                        onChanged: (v) => setState(() => _manualProgress = v),
                      ),
                    ),
                    Text('${(_manualProgress * 100).round()}%'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: _saving
                ? null
                : () async {
                    await ref
                        .read(goalRepositoryProvider)
                        .softDeleteGoal(widget.existing!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.existing == null ? '创建' : '保存'),
        ),
      ],
    );
  }
}
