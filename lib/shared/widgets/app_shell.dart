import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../features/daily/daily_page.dart';
import '../../features/daily/task_detail_panel.dart';
import '../../features/monthly/monthly_page.dart';
import '../../features/semester/semester_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/weekly/weekly_page.dart';
import '../providers/app_providers.dart';
import 'goal_editor_dialog.dart';
import 'google_brand_widgets.dart';
import 'sync_indicator.dart';
import 'task_editor_dialog.dart';

/// Google Material You 双端自适应主壳：
/// - Windows 桌面端：Google Workspace / Calendar 风格悬浮圆角画布 + 左侧四色「+ 新建」按钮 + 胶囊导航栏 + 右侧圆角详情抽屉
/// - Android 移动端：Google Tasks 风格四色顶栏 + 动态色彩胶囊底栏 + 四色「+ 新建」扩展悬浮按钮
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  void _openQuickCreate(BuildContext context, WidgetRef ref) {
    final section = ref.read(activeNavProvider);
    switch (section) {
      case NavSection.daily:
        final date = ref.read(selectedDateProvider);
        TaskEditorDialog.show(
          context,
          initialScheduledDate: TermDateUtils.formatIsoDate(date),
        );
      case NavSection.weekly:
        final weekStart = ref.read(selectedWeekStartProvider);
        TaskEditorDialog.show(
          context,
          initialWeekStartDate: TermDateUtils.formatIsoDate(weekStart),
        );
      case NavSection.monthly:
        final month = ref.read(selectedMonthProvider);
        GoalEditorDialog.show(
          context,
          level: GoalLevel.monthly,
          targetYear: month.year,
          targetMonth: month.month,
        );
      case NavSection.semester:
        final sem = ref.read(activeSemesterProvider).valueOrNull;
        GoalEditorDialog.show(
          context,
          level: GoalLevel.semester,
          defaultSemesterId: sem?.id,
        );
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  void _showPaletteQuickSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final currentSeed = ref.watch(themeSeedProvider);
          final currentMode = ref.watch(themeModeProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Material You 主题色板',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: GoogleThemeSeed.values.map((seed) {
                    final selected = seed == currentSeed;
                    return InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () =>
                          ref.read(themeSeedProvider.notifier).setSeed(seed),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: seed.seedColor.withAlpha(selected ? 40 : 18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? seed.seedColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: seed.seedColor,
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              seed.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('自动'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('浅色'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('深色'),
                    ),
                  ],
                  selected: {currentMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).setMode(s.first),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(NavSection section) {
    return switch (section) {
      NavSection.daily => const DailyPage(),
      NavSection.weekly => const WeeklyPage(),
      NavSection.monthly => const MonthlyPage(),
      NavSection.semester => const SemesterPage(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncControllerProvider);

    final section = ref.watch(activeNavProvider);
    final isDesktop = Responsive.isDesktop(context);

    final content = isDesktop
        ? _DesktopScaffold(
            section: section,
            mainBody: _buildMainContent(section),
            onOpenSettings: () => _openSettings(context),
            onOpenPalette: () => _showPaletteQuickSheet(context, ref),
            onQuickCreate: () => _openQuickCreate(context, ref),
          )
        : _MobileScaffold(
            section: section,
            mainBody: _buildMainContent(section),
            onOpenSettings: () => _openSettings(context),
            onOpenPalette: () => _showPaletteQuickSheet(context, ref),
            onFabPressed: () => _openQuickCreate(context, ref),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _openQuickCreate(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _openQuickCreate(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: content,
      ),
    );
  }
}

class _DesktopScaffold extends ConsumerWidget {
  const _DesktopScaffold({
    required this.section,
    required this.mainBody,
    required this.onOpenSettings,
    required this.onOpenPalette,
    required this.onQuickCreate,
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPalette;
  final VoidCallback onQuickCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final showRightPanel = section == NavSection.daily;
    final theme = Theme.of(context);

    String? currentWeekLabel;
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: DateTime.now(),
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) currentWeekLabel = '第 $w 周';
    }

    final createLabel = switch (section) {
      NavSection.daily => '新建任务',
      NavSection.weekly => '新建周待办',
      NavSection.monthly => '新建月目标',
      NavSection.semester => '新建学期目标',
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: Row(
        children: [
          // 1. Google Workspace 风格左侧导航抽屉
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 品牌栏 + 调色盘按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      const GoogleBrandLogo(size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TermFlow',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (activeSemester != null)
                              Text(
                                currentWeekLabel != null
                                    ? '${activeSemester.name} · $currentWeekLabel'
                                    : activeSemester.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '切换 Material You 主题色',
                        onPressed: onOpenPalette,
                        icon: Icon(
                          Icons.palette_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Google Calendar / Gmail 标志性的左上角悬浮四色「+ 新建」大胶囊按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 24, 14),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLowest,
                    elevation: 2,
                    shadowColor: Colors.black.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onQuickCreate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 13),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GooglePlusIcon(size: 22),
                            const SizedBox(width: 12),
                            Text(
                              createLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 四级时间维度多彩胶囊导航
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: NavSection.values.map((nav) {
                      final active = nav == section;
                      final accent = nav.accentColor;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: active
                              ? accent.withAlpha(
                                  theme.brightness == Brightness.dark ? 52 : 32)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => ref
                                .read(activeNavProvider.notifier)
                                .state = nav,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              child: Row(
                                children: [
                                  Icon(
                                    active ? nav.selectedIcon : nav.icon,
                                    size: 21,
                                    color: active
                                        ? accent
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      nav.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? accent
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (active)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 18, 8),
                  child: Text(
                    '多彩标签',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.hintColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                // 多彩标签列表
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _SidebarTagPill(
                        label: '全部事项',
                        color: theme.colorScheme.primary,
                        isAllIcon: true,
                        selected: selectedTagId == null,
                        onTap: () {
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref.read(activeNavProvider.notifier).state =
                              NavSection.daily;
                        },
                      ),
                      ...tags.map((tag) {
                        final color = AppTheme.parseHex(tag.colorHex);
                        final active = selectedTagId == tag.id;
                        return _SidebarTagPill(
                          label: tag.name,
                          color: color,
                          selected: active,
                          onTap: () {
                            ref.read(selectedTagFilterProvider.notifier).state =
                                active ? null : tag.id;
                            ref.read(activeNavProvider.notifier).state =
                                NavSection.daily;
                          },
                        );
                      }),
                    ],
                  ),
                ),

                // 底部云端同步指示胶囊 + 设置按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    children: [
                      const SyncIndicator(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('设置与云端同步'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 中间悬浮圆角主画布（Google Workspace 圆角卡片窗口美学）
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                10,
                showRightPanel ? 8 : 12,
                10,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  child: mainBody,
                ),
              ),
            ),
          ),

          // 3. 右侧悬浮圆角任务详情面板
          if (showRightPanel)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
              child: SizedBox(
                width: Responsive.isWideDesktop(context) ? 364 : 316,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: selectedTaskId == null
                      ? ColoredBox(
                          color: theme.colorScheme.surfaceContainerLowest,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const GoogleBrandLogo(size: 40),
                                  const SizedBox(height: 16),
                                  Text(
                                    '选择一条任务',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '在此查看详细笔记、优先级\n与四级目标溯源进度',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : TaskDetailPanel(
                          taskId: selectedTaskId,
                          onClose: () => ref
                              .read(selectedTaskIdProvider.notifier)
                              .state = null,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarTagPill extends StatelessWidget {
  const _SidebarTagPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.isAllIcon = false,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isAllIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? color.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (isAllIcon)
                  Icon(Icons.auto_awesome_mosaic_rounded,
                      size: 16, color: color)
                else
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileScaffold extends ConsumerWidget {
  const _MobileScaffold({
    required this.section,
    required this.mainBody,
    required this.onOpenSettings,
    required this.onOpenPalette,
    required this.onFabPressed,
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPalette;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const GoogleBrandLogo(size: 26),
            const SizedBox(width: 10),
            Text(
              'TermFlow',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          const SyncIndicator(compact: true),
          IconButton(
            tooltip: '切换多彩主题',
            onPressed: onOpenPalette,
            icon: Icon(
              Icons.palette_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: '设置与账号',
              onPressed: onOpenSettings,
              icon: CircleAvatar(
                radius: 15,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: mainBody,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onFabPressed,
        icon: const GooglePlusIcon(size: 22),
        label: const Text(
          '新建',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: NavSection.values.indexOf(section),
        indicatorColor: section.accentColor.withAlpha(
          theme.brightness == Brightness.dark ? 64 : 38,
        ),
        onDestinationSelected: (idx) {
          ref.read(activeNavProvider.notifier).state = NavSection.values[idx];
        },
        destinations: NavSection.values
            .map(
              (nav) => NavigationDestination(
                icon: Icon(nav.icon),
                selectedIcon: Icon(nav.selectedIcon, color: nav.accentColor),
                label: nav.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
