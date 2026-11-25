import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../features/daily/daily_page.dart';
import '../../features/daily/task_detail_panel.dart';
import '../../features/monthly/monthly_page.dart';
import '../../features/semester/semester_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/weekly/weekly_page.dart';
import '../providers/app_providers.dart';
import 'gemini_components.dart';
import 'goal_editor_dialog.dart';
import 'google_brand_widgets.dart';
import 'sync_indicator.dart';
import 'task_editor_dialog.dart';

/// Google Gemini App 风格双端自适应毛玻璃主壳
/// 底层透明以透出全局 GLSL 液态网格极光，侧边栏、底栏与抽屉均采用 24px 高斯模糊半透明色调表面
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  Future<void> _openQuickCreate(BuildContext context, WidgetRef ref) async {
    final section = ref.read(activeNavProvider);
    ref.read(geminiFocusPointProvider.notifier).state = const Offset(0.5, 0.50);
    ref.read(geminiFocusActiveProvider.notifier).state = true;
    try {
      switch (section) {
        case NavSection.daily:
          final date = ref.read(selectedDateProvider);
          await TaskEditorDialog.show(
            context,
            initialScheduledDate: TermDateUtils.formatIsoDate(date),
          );
        case NavSection.weekly:
          final weekStart = ref.read(selectedWeekStartProvider);
          await TaskEditorDialog.show(
            context,
            initialWeekStartDate: TermDateUtils.formatIsoDate(weekStart),
          );
        case NavSection.monthly:
          final month = ref.read(selectedMonthProvider);
          await GoalEditorDialog.show(
            context,
            level: GoalLevel.monthly,
            targetYear: month.year,
            targetMonth: month.month,
          );
        case NavSection.semester:
          final sem = ref.read(activeSemesterProvider).valueOrNull;
          await GoalEditorDialog.show(
            context,
            level: GoalLevel.semester,
            defaultSemesterId: sem?.id,
          );
      }
    } finally {
      ref.read(geminiFocusActiveProvider.notifier).state = false;
    }
  }

  void _openAccountSettings(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: GeminiTokens.mediumDuration,
        reverseTransitionDuration: GeminiTokens.fastDuration,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: GeminiTokens.springCurve,
          ),
          child: const SettingsPage(),
        ),
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

    final bodyWidget = AnimatedSwitcher(
      duration: GeminiTokens.fastDuration,
      switchInCurve: GeminiTokens.springCurve,
      child: KeyedSubtree(
        key: ValueKey(section),
        child: _buildMainContent(section),
      ),
    );

    final content = isDesktop
        ? _DesktopScaffold(
            section: section,
            mainBody: bodyWidget,
            onOpenAccount: () => _openAccountSettings(context),
            onQuickCreate: () => _openQuickCreate(context, ref),
          )
        : _MobileScaffold(
            section: section,
            mainBody: bodyWidget,
            onOpenAccount: () => _openAccountSettings(context),
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
    required this.onOpenAccount,
    required this.onQuickCreate,
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenAccount;
  final VoidCallback onQuickCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final authState = ref.watch(supabaseManagerProvider);
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final selectedTagId = ref.watch(selectedTagFilterProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final showRightPanel =
        section == NavSection.daily && selectedTaskId != null;
    final tokens = GeminiTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    int? weekNum;
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: DateTime.now(),
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) weekNum = w;
    }

    final avatarLabel = authState.user?.email?.split('@').first ?? 'TF';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // 1. 悬浮毛玻璃侧边导航栏（24px 高斯模糊 + 1px 微光描边）
          SizedBox(
            width: 280,
            child: GeminiGlassCard(
              margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
              borderRadius: BorderRadius.circular(28),
              blurSigma: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部 Gemini 星芒标识 + 教学周胶囊 + 光环头像
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                    child: Row(
                      children: [
                        const GeminiSparkleIcon(size: 24, animate: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'TermFlow',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        if (weekNum != null) ...[
                          ChromeCounterBadge(
                            text: '$weekNum',
                            tooltip: '当前第 $weekNum 教学周',
                            onTap: () => ref
                                .read(activeNavProvider.notifier)
                                .state = NavSection.semester,
                          ),
                        ],
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onOpenAccount,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: GoogleRingAvatar(
                              text: avatarLabel,
                              size: 33,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 核心 CTA 胶囊按钮（克制使用蓝紫流光渐变）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            GeminiTokens.electricBlue.withAlpha(
                              tokens.isDark ? 72 : 34,
                            ),
                            GeminiTokens.cobaltViolet.withAlpha(
                              tokens.isDark ? 72 : 34,
                            ),
                            GeminiTokens.softViolet.withAlpha(
                              tokens.isDark ? 58 : 28,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: tokens.glassHighlightBorder,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onQuickCreate,
                          child: SizedBox(
                            height: 48,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: Row(
                                children: [
                                  const GeminiSparkleIcon(
                                    size: 19,
                                    animate: true,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '新建计划',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Ctrl+N',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 四级时间维度胶囊切换
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: NavSection.values.map((nav) {
                        final active = nav == section;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: AnimatedContainer(
                            duration: GeminiTokens.fastDuration,
                            curve: GeminiTokens.springCurve,
                            decoration: BoxDecoration(
                              color: active
                                  ? scheme.secondaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              border: active
                                  ? Border.all(color: tokens.glassBorder)
                                  : null,
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => ref
                                    .read(activeNavProvider.notifier)
                                    .state = nav,
                                child: SizedBox(
                                  height: 46,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          active ? nav.selectedIcon : nav.icon,
                                          size: 20,
                                          color: active
                                              ? tokens.textPrimary
                                              : tokens.textSecondary,
                                        ),
                                        const SizedBox(width: 13),
                                        Expanded(
                                          child: Text(
                                            nav.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: active
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: active
                                                  ? tokens.textPrimary
                                                  : tokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                      '标签筛选',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        _GlassTagRow(
                          label: '全部事项',
                          dotColor: null,
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
                          return _GlassTagRow(
                            label: tag.name,
                            dotColor: color,
                            selected: active,
                            onTap: () {
                              ref
                                  .read(selectedTagFilterProvider.notifier)
                                  .state = active ? null : tag.id;
                              ref.read(activeNavProvider.notifier).state =
                                  NavSection.daily;
                            },
                          );
                        }),
                      ],
                    ),
                  ),

                  // 底部毛玻璃同步胶囊 + 设置按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                    child: Column(
                      children: [
                        const SyncIndicator(),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: onOpenAccount,
                            icon: const Icon(Icons.tune_rounded, size: 17),
                            label: const Text('外观与云同步设置'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 通透主舞台（直接展示在 GLSL 流体动态背景之上）
          Expanded(child: mainBody),

          // 3. 右侧按需展开的毛玻璃任务详情抽屉
          if (showRightPanel)
            SizedBox(
              width: Responsive.isWideDesktop(context) ? 384 : 336,
              child: GeminiGlassCard(
                margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 24,
                child: TaskDetailPanel(
                  taskId: selectedTaskId,
                  onClose: () =>
                      ref.read(selectedTaskIdProvider.notifier).state = null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassTagRow extends StatelessWidget {
  const _GlassTagRow({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (dotColor == null)
                    Icon(
                      Icons.checklist_rounded,
                      size: 17,
                      color: tokens.textSecondary,
                    )
                  else
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color:
                            selected ? tokens.textPrimary : tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
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
    required this.onOpenAccount,
    required this.onFabPressed,
  });

  final NavSection section;
  final Widget mainBody;
  final VoidCallback onOpenAccount;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
    final authState = ref.watch(supabaseManagerProvider);
    final tokens = GeminiTokens.of(context);
    final avatarLabel = authState.user?.email?.split('@').first ?? 'TF';

    int weekNum = 1;
    if (activeSemester != null) {
      final w = TermDateUtils.teachingWeekIndex(
        targetDate: DateTime.now(),
        semesterStart: TermDateUtils.parseIsoDate(activeSemester.startDate),
        weekStartsOn: activeSemester.weekStartsOn,
      );
      if (w >= 1) weekNum = w;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '回到今日计划',
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state =
                TermDateUtils.dateOnly(DateTime.now());
            ref.read(activeNavProvider.notifier).state = NavSection.daily;
          },
          icon: const GeminiSparkleIcon(size: 22, animate: true),
        ),
        title: Text(
          'TermFlow',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          const SyncIndicator(compact: true),
          ChromeCounterBadge(
            text: '$weekNum',
            tooltip: '第 $weekNum 教学周',
            onTap: () => ref.read(activeNavProvider.notifier).state =
                NavSection.semester,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onOpenAccount,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
              child: GoogleRingAvatar(
                text: avatarLabel,
                size: 32,
                ringWidth: 2.0,
              ),
            ),
          ),
        ],
      ),
      body: mainBody,
      floatingActionButton: GeminiGlassCard(
        borderRadius: BorderRadius.circular(999),
        blurSigma: 24,
        isHighlighted: true,
        backgroundColor: tokens.glassElevated,
        onTap: onFabPressed,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GeminiSparkleIcon(size: 20, animate: true),
            const SizedBox(width: 9),
            Text(
              '新建',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.glassElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.glassBorder),
                ),
                child: NavigationBar(
                  height: 66,
                  selectedIndex: NavSection.values.indexOf(section),
                  onDestinationSelected: (idx) {
                    ref.read(activeNavProvider.notifier).state =
                        NavSection.values[idx];
                  },
                  destinations: NavSection.values
                      .map(
                        (nav) => NavigationDestination(
                          icon: Icon(
                            nav.icon,
                            size: 22,
                            color: tokens.textSecondary,
                          ),
                          selectedIcon: Icon(
                            nav.selectedIcon,
                            size: 22,
                            color: tokens.textPrimary,
                          ),
                          label: nav.label,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
