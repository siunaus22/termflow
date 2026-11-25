import 'package:flutter/material.dart';

/// Gemini 核心主题变体
enum GoogleThemeSeed {
  geminiAurora('gemini_aurora', 'Gemini 星云蓝紫', Color(0xFF6B7CFF)),
  electricBlue('electric_blue', '电光深海蓝', Color(0xFF4285F4)),
  nebulaViolet('nebula_violet', '极光紫罗兰', Color(0xFF9B72CB)),
  glacierCyan('glacier_cyan', '冰川浅青蓝', Color(0xFF4FACFE));

  const GoogleThemeSeed(this.key, this.label, this.seedColor);
  final String key;
  final String label;
  final Color seedColor;

  static GoogleThemeSeed fromKey(String k) =>
      GoogleThemeSeed.values.firstWhere(
        (e) => e.key == k,
        orElse: () => GoogleThemeSeed.geminiAurora,
      );
}

enum GoalLevel {
  semester('semester', '学期目标', Color(0xFF9B72CB)),
  monthly('monthly', '月度目标', Color(0xFF6B7CFF)),
  weekly('weekly', '周目标', Color(0xFF4285F4));

  const GoalLevel(this.value, this.label, this.accentColor);
  final String value;
  final String label;
  final Color accentColor;

  static GoalLevel fromString(String v) => GoalLevel.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalLevel.weekly,
      );
}

enum GoalCategory {
  academic(
    'academic',
    '学业',
    Color(0xFF4285F4),
    '#4285F4',
    Icons.school_outlined,
  ),
  project(
    'project',
    '项目',
    Color(0xFF4FACFE),
    '#4FACFE',
    Icons.rocket_launch_outlined,
  ),
  competition(
    'competition',
    '竞赛',
    Color(0xFF9B72CB),
    '#9B72CB',
    Icons.emoji_events_outlined,
  ),
  life(
    'life',
    '生活',
    Color(0xFF5BB98C),
    '#5BB98C',
    Icons.spa_outlined,
  ),
  other(
    'other',
    '探索',
    Color(0xFFD96570),
    '#D96570',
    Icons.auto_awesome_outlined,
  );

  const GoalCategory(
    this.value,
    this.label,
    this.color,
    this.colorHex,
    this.icon,
  );
  final String value;
  final String label;
  final Color color;
  final String colorHex;
  final IconData icon;

  static GoalCategory fromString(String v) => GoalCategory.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalCategory.other,
      );
}

enum TaskPriority {
  p0(0, 'P0', '紧急重要', Color(0xFFD96570)),
  p1(1, 'P1', '重要优先', Color(0xFF9B72CB)),
  p2(2, 'P2', '常规推进', Color(0xFF4285F4)),
  p3(3, 'P3', '轻松日常', Color(0xFF4FACFE));

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
  daily(
    '日计划',
    Icons.wb_sunny_outlined,
    Icons.wb_sunny_rounded,
    Color(0xFF4285F4),
  ),
  weekly(
    '周计划',
    Icons.view_week_outlined,
    Icons.view_week_rounded,
    Color(0xFF6B7CFF),
  ),
  monthly(
    '月计划',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
    Color(0xFF9B72CB),
  ),
  semester(
    '学期计划',
    Icons.school_outlined,
    Icons.school_rounded,
    Color(0xFF4FACFE),
  );

  const NavSection(this.label, this.icon, this.selectedIcon, this.accentColor);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;
}
