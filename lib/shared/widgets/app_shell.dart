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
import 'sync_indicator.dart';
import 'task_editor_dialog.dart';

/// 双端自适应主壳：
/// - Windows 桌面端：左侧固定导航栏（四级切换 + 标签筛选 + 同步指示灯）+ 中间主列表区 + 右侧任务详情与目标溯源面板；支持 Ctrl+N 快速新建
/// - Android 移动端：顶部精简栏 + 底部四级导航栏 + 右下角 FAB 快速添加
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
    // 激活后台同步控制器（网络监听 + Realtime 监听）
    ref.watch(syncControllerProvider);

    final section = ref.watch(activeNavProvider);
    final isDesktop = Responsive.isDesktop(context);

    final content = isDesktop
        ? _DesktopScaffold(
            section: section,
            mainBody: _buildMainContent(section),
            onOpenSettings: () => _openSettings(context),
          )
        : _MobileScaffold(
            section: section,
            mainBody: _buildMainContent(section),
            onOpenSettings: () => _openSettings(context),
            onFabPressed: () => _openQuickCreate(context, ref),
          );

    // 全局快捷键支持：Ctrl+N 快速新建任务/目标
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
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final showRightPanel = section == NavSection.daily;

    String? currentWeekLabel;
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: DateTime.now(),
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) currentWeekLabel = '第 $w 周';
    }

    return Scaffold(
      body: Row(
        children: [
          // 1. 左侧固定导航栏
          Container(
            width: 244,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 品牌 Header + 当前学期教学周徽章
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.layers_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TermFlow',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (activeSemester != null)
                              Text(
                                currentWeekLabel != null
                                    ? '${activeSemester.name} · $currentWeekLabel'
                                    : activeSemester.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 四级时间维度导航
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: NavSection.values.map((nav) {
                      final active = nav == section;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: ListTile(
                          dense: true,
                          selected: active,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selectedTileColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(28),
                          leading: Icon(
                            nav.icon,
                            size: 20,
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            nav.label,
                            style: TextStyle(
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          onTap: () =>
                              ref.read(activeNavProvider.notifier).state = nav,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Text(
                    '标签筛选',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // 标签列表
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected: selectedTagId == null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.label_outline, size: 17),
                        title: const Text('全部标签', style: TextStyle(fontSize: 13)),
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
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          selected: active,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            tag.name,
                            style: const TextStyle(fontSize: 13),
                          ),
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

                // 底部同步状态指示灯 + 设置入口
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: [
                      const SyncIndicator(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_outlined, size: 17),
                          label: const Text('设置与云端配置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // 2. 中间主内容区
          Expanded(flex: 5, child: mainBody),

          // 3. 右侧任务详情与目标溯源面板（仅在日计划视图展示）
          if (showRightPanel) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: Responsive.isWideDesktop(context) ? 360 : 310,
              child: selectedTaskId == null
                  ? Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 40,
                              color: Theme.of(context).hintColor.withAlpha(110),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '点击左侧任务查看详情\n并编辑关联周/月/学期目标',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TaskDetailPanel(
                      taskId: selectedTaskId,
                      onClose: () =>
                          ref.read(selectedTaskIdProvider.notifier).state = null,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileScaffold extends ConsumerWidget {
  const _MobileScaffold({
    required this.section,
    required this.mainBody,
    required this.onOpenSettings,
    required this.onFabPressed,
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenSettings;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.layers_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'TermFlow',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          const SyncIndicator(compact: true),
          IconButton(
            tooltip: '设置与云端同步',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: mainBody,
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        tooltip: '快速新建',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: NavSection.values.indexOf(section),
        onDestinationSelected: (idx) {
          ref.read(activeNavProvider.notifier).state = NavSection.values[idx];
        },
        destinations: NavSection.values
            .map(
              (nav) => NavigationDestination(
                icon: Icon(nav.icon),
                label: nav.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
