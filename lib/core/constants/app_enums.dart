import 'package:flutter/material.dart';

enum GoalLevel {
  semester('semester', '学期目标'),
  monthly('monthly', '月度目标'),
  weekly('weekly', '周目标');

  const GoalLevel(this.value, this.label);
  final String value;
  final String label;

  static GoalLevel fromString(String v) => GoalLevel.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalLevel.weekly,
      );
}

enum GoalCategory {
  academic('academic', '学业', Color(0xFF4F6BED), '#4F6BED'),
  project('project', '项目', Color(0xFF0EA5E9), '#0EA5E9'),
  competition('competition', '竞赛', Color(0xFFF59E0B), '#F59E0B'),
  life('life', '生活', Color(0xFF10B981), '#10B981'),
  other('other', '其他', Color(0xFF64748B), '#64748B');

  const GoalCategory(this.value, this.label, this.color, this.colorHex);
  final String value;
  final String label;
  final Color color;
  final String colorHex;

  static GoalCategory fromString(String v) => GoalCategory.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalCategory.other,
      );
}

enum TaskPriority {
  p0(0, 'P0', '紧急重要', Color(0xFFEF4444)),
  p1(1, 'P1', '高优先级', Color(0xFFF97316)),
  p2(2, 'P2', '中优先级', Color(0xFF3B82F6)),
  p3(3, 'P3', '低优先级', Color(0xFF94A3B8));

  const TaskPriority(this.value, this.code, this.label, this.color);
  final int value;
  final String code;
  final String label;
  final Color color;

  static TaskPriority fromInt(int v) => TaskPriority.values.firstWhere(
        (e) => e.value == v,
        orElse: () => TaskPriority.p2,
      );
}

enum SyncStatusValue {
  synced('synced'),
  pending('pending');

  const SyncStatusValue(this.value);
  final String value;
}

enum NavSection {
  daily('日计划', Icons.today_rounded),
  weekly('周计划', Icons.view_week_rounded),
  monthly('月计划', Icons.calendar_month_rounded),
  semester('学期计划', Icons.school_rounded);

  const NavSection(this.label, this.icon);
  final String label;
  final IconData icon;
}
