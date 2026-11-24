import 'package:flutter/material.dart';

/// Google Material You 可选主题色板
enum GoogleThemeSeed {
  googleBlue('google_blue', 'Google 经典蓝', Color(0xFF1A73E8)),
  mintGreen('mint_green', '薄荷森绿', Color(0xFF1E8E3E)),
  lavenderIris('lavender_iris', '星云鸢尾紫', Color(0xFF7C4DFF)),
  sunsetCoral('sunset_coral', '落日珊瑚红', Color(0xFFE8453C)),
  oceanTeal('ocean_teal', '海岸青碧', Color(0xFF00897B)),
  amberGold('amber_gold', '暖阳琥珀金', Color(0xFFE37400));

  const GoogleThemeSeed(this.key, this.label, this.seedColor);
  final String key;
  final String label;
  final Color seedColor;

  static GoogleThemeSeed fromKey(String k) =>
      GoogleThemeSeed.values.firstWhere(
        (e) => e.key == k,
        orElse: () => GoogleThemeSeed.googleBlue,
      );
}

enum GoalLevel {
  semester('semester', '学期目标', Color(0xFFE37400)),
  monthly('monthly', '月度目标', Color(0xFF1E8E3E)),
  weekly('weekly', '周目标', Color(0xFF9334E6));

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
    Color(0xFF1A73E8),
    '#1A73E8',
    Icons.menu_book_rounded,
  ),
  project(
    'project',
    '项目',
    Color(0xFF00897B),
    '#00897B',
    Icons.rocket_launch_rounded,
  ),
  competition(
    'competition',
    '竞赛',
    Color(0xFFF9AB00),
    '#F9AB00',
    Icons.emoji_events_rounded,
  ),
  life(
    'life',
    '生活',
    Color(0xFF34A853),
    '#34A853',
    Icons.spa_rounded,
  ),
  other(
    'other',
    '探索',
    Color(0xFF9334E6),
    '#9334E6',
    Icons.auto_awesome_rounded,
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
  p0(0, 'P0', '紧急重要', Color(0xFFEA4335)), // Google Red
  p1(1, 'P1', '高优先级', Color(0xFFFA7B17)), // Google Orange/Amber
  p2(2, 'P2', '中优先级', Color(0xFF4285F4)), // Google Blue
  p3(3, 'P3', '轻松日常', Color(0xFF34A853)); // Google Green

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

/// 四级计划导航维度，每一级拥有专属 Google 主题色与空心/实心双态图标
enum NavSection {
  daily(
    '日计划',
    Icons.wb_sunny_outlined,
    Icons.wb_sunny_rounded,
    Color(0xFF1A73E8), // Google Blue
  ),
  weekly(
    '周计划',
    Icons.view_week_outlined,
    Icons.view_week_rounded,
    Color(0xFF9334E6), // Google Purple
  ),
  monthly(
    '月计划',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
    Color(0xFF1E8E3E), // Google Green
  ),
  semester(
    '学期计划',
    Icons.school_outlined,
    Icons.school_rounded,
    Color(0xFFE37400), // Google Amber
  );

  const NavSection(this.label, this.icon, this.selectedIcon, this.accentColor);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;
}
