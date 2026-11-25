import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gemini_tokens.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/gemini_components.dart';
import '../../shared/widgets/google_brand_widgets.dart';

/// Google Gemini App 毛玻璃设置与云端账号中心
/// 支持深/浅色一键切换、动态流体极光无障碍开关、Supabase 云同步与账号管理
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  void _showSupabaseSheet(BuildContext context) {
    final store = ref.read(appConfigStoreProvider);
    final urlCtrl = TextEditingController(text: store.supabaseUrl);
    final keyCtrl = TextEditingController(text: store.supabaseAnonKey);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        var connecting = false;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: StatefulBuilder(
            builder: (ctx, setModalState) => Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                4,
                24,
                MediaQuery.viewInsetsOf(ctx).bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      GeminiSparkleIcon(size: 20, animate: true),
                      SizedBox(width: 10),
                      Text(
                        '配置 Supabase 云同步服务',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '填入你的 Project URL 与 Publishable / Anon Key，即可在 Windows 与 Android 间双向同步。',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: GeminiTokens.of(ctx).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SUPABASE_URL',
                      hintText: 'https://your-project.supabase.co',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'SUPABASE_ANON_KEY',
                      hintText: 'sb_publishable_... 或 eyJhbG...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: GeminiTokens.cobaltViolet,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: connecting
                          ? null
                          : () async {
                              final url = urlCtrl.text.trim();
                              final key = keyCtrl.text.trim();
                              if (url.isEmpty || key.isEmpty) return;
                              setModalState(() => connecting = true);
                              await store.saveSupabaseConfig(
                                  url: url, anonKey: key);
                              final ok = await ref
                                  .read(supabaseManagerProvider.notifier)
                                  .connect(url: url, anonKey: key);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Supabase 服务已连接，现在可以登录账号'
                                          : '连接失败，请核对 URL 和 Key',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(connecting ? '正在连接...' : '保存并连接'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAuthSheet(BuildContext context) {
    final authState = ref.read(supabaseManagerProvider);
    if (!authState.isInitialized) {
      _showSupabaseSheet(context);
      return;
    }

    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        var isSignUp = false;
        var loading = false;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: StatefulBuilder(
            builder: (ctx, setModalState) => Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                4,
                24,
                MediaQuery.viewInsetsOf(ctx).bottom + 28,
              ),
              child: authState.isLoggedIn
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoogleRingAvatar(
                          text: authState.user?.email?.split('@').first ?? 'U',
                          size: 68,
                          ringWidth: 2.8,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          authState.user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(supabaseManagerProvider.notifier)
                                  .signOut();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('退出当前云端账号'),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSignUp ? '注册云端同步账号' : '登录云端同步账号',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: '邮箱地址'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: '密码（至少 6 位）'),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setModalState(() => isSignUp = !isSignUp),
                              child: Text(isSignUp ? '已有账号？去登录' : '注册新账号'),
                            ),
                            const Spacer(),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: GeminiTokens.cobaltViolet,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final email = emailCtrl.text.trim();
                                      final pwd = pwdCtrl.text;
                                      if (email.isEmpty || pwd.length < 6) {
                                        return;
                                      }
                                      setModalState(() => loading = true);
                                      final mgr = ref.read(
                                          supabaseManagerProvider.notifier);
                                      final err = isSignUp
                                          ? await mgr.signUp(email, pwd)
                                          : await mgr.signIn(email, pwd);
                                      if (!ctx.mounted) return;
                                      if (err != null) {
                                        setModalState(() => loading = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('认证失败：$err')),
                                        );
                                      } else {
                                        Navigator.of(ctx).pop();
                                        await ref
                                            .read(
                                                syncControllerProvider.notifier)
                                            .syncNow();
                                      }
                                    },
                              child: Text(loading
                                  ? '请稍候...'
                                  : (isSignUp ? '注册并同步' : '登录并同步')),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _showTagsSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    var selectedHex = AppTheme.tagPalette.first.$2;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Consumer(
          builder: (ctx, ref, _) {
            final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
            return StatefulBuilder(
              builder: (ctx, setModalState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  MediaQuery.viewInsetsOf(ctx).bottom + 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '管理分类标签',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppTheme.tagPalette.map((item) {
                        final active = selectedHex == item.$2;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedHex = item.$2),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: item.$3,
                              shape: BoxShape.circle,
                              border: active
                                  ? Border.all(color: Colors.white, width: 2.2)
                                  : null,
                            ),
                            child: active
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              hintText: '输入新标签名称...',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: GeminiTokens.cobaltViolet,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final v = nameCtrl.text.trim();
                            if (v.isEmpty) return;
                            await ref.read(tagRepositoryProvider).createTag(
                                  name: v,
                                  colorHex: selectedHex,
                                );
                            nameCtrl.clear();
                          },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final color = AppTheme.parseHex(tag.colorHex);
                        return InputChip(
                          avatar:
                              CircleAvatar(radius: 5, backgroundColor: color),
                          label: Text(tag.name),
                          onDeleted: () => ref
                              .read(tagRepositoryProvider)
                              .softDeleteTag(tag.id),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(supabaseManagerProvider);
    final syncState = ref.watch(syncControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeSeed = ref.watch(themeSeedProvider);
    final motionEnabled = ref.watch(ambientMotionProvider);
    final configStore = ref.watch(appConfigStoreProvider);
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;

    final tokens = GeminiTokens.of(context);
    final emailText = authState.user?.email ?? '本地离线模式 (未连接云端账号)';
    final displayName = authState.user?.email?.split('@').first ?? '探索者';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Scaffold(
        backgroundColor:
            tokens.baseCanvas.withAlpha(tokens.isDark ? 226 : 234),
        appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          emailText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 48),
            children: [
              // 1. 头部光环头像与欢迎语
              Center(
                child: GoogleRingAvatar(
                  text: displayName,
                  size: 84,
                  ringWidth: 3.0,
                  showCameraBadge: true,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: GeminiGradientText(
                  '$displayName，你好',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!authState.isLoggedIn) {
                      _showAuthSheet(context);
                      return;
                    }
                    final res = await ref
                        .read(syncControllerProvider.notifier)
                        .syncNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res.success
                                ? '同步完成：拉取 ${res.pulledCount} 条 · 推送 ${res.pushedCount} 条'
                                : '同步失败：${res.errorMessage}',
                          ),
                        ),
                      );
                    }
                  },
                  icon: syncState.phase == SyncUiPhase.syncing
                      ? const GeminiSparkleIcon(
                          size: 16,
                          spin: true,
                          animate: true,
                        )
                      : const GeminiSparkleIcon(size: 16),
                  label: Text(
                    authState.isLoggedIn
                        ? (syncState.phase == SyncUiPhase.syncing
                            ? '正在云端同步...'
                            : '立即手动同步')
                        : '登录 / 注册云同步账号',
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 2. 外观与动态流体极光控制卡（深/浅色一键切换 + GLSL 动态开关）
              GeminiGlassCard(
                borderRadius: BorderRadius.circular(26),
                blurSigma: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const GeminiSparkleIcon(size: 18, animate: true),
                        const SizedBox(width: 8),
                        Text(
                          'Gemini 视觉与流体极光',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined, size: 17),
                            label: Text('深色'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined, size: 17),
                            label: Text('浅色'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon:
                                Icon(Icons.brightness_auto_outlined, size: 17),
                            label: Text('自动'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (s) => ref
                            .read(themeModeProvider.notifier)
                            .setMode(s.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GoogleThemeSeed.values.map((seed) {
                        final selected = seed == themeSeed;
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: seed.seedColor,
                          ),
                          label: Text(seed.label),
                          selected: selected,
                          onSelected: (_) => ref
                              .read(themeSeedProvider.notifier)
                              .setSeed(seed),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '流体极光动态背景 (GLSL Shader)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: tokens.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '关闭后将降级为静态柔和弥散光晕，降低功耗与视觉运动',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                      value: motionEnabled,
                      onChanged: (v) =>
                          ref.read(ambientMotionProvider.notifier).setEnabled(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Supabase 云服务连接卡片
              GeminiGlassCard(
                borderRadius: BorderRadius.circular(26),
                blurSigma: 24,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                onTap: () => _showSupabaseSheet(context),
                child: Row(
                  children: [
                    const GeminiSparkleIcon(size: 24, animate: true),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.isInitialized
                                ? 'Supabase 云同步服务已连接'
                                : '配置 Supabase 多设备实时同步',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '点击填写 SUPABASE_URL 与 Publishable / Anon Key',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: tokens.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. 分段毛玻璃设置菜单
              M3SegmentedColumn(
                children: [
                  _GlassMenuRow(
                    icon: Icons.manage_accounts_outlined,
                    title: authState.isLoggedIn ? '切换或退出云端账号' : '登录 / 注册云端账号',
                    trailingText: authState.isLoggedIn ? '已登录' : '未登录',
                    onTap: () => _showAuthSheet(context),
                  ),
                  _GlassMenuRow(
                    icon: Icons.cloud_upload_outlined,
                    title: '待同步本地变更数',
                    trailingText: '$pendingCount',
                    onTap: () =>
                        ref.read(syncControllerProvider.notifier).syncNow(),
                  ),
                  _GlassMenuRow(
                    icon: Icons.sell_outlined,
                    title: '分类标签管理',
                    trailingText: '${tags.length}',
                    onTap: () => _showTagsSheet(context),
                  ),
                  _GlassMenuRow(
                    icon: Icons.sync_outlined,
                    title: '后台自动云同步',
                    trailingText: configStore.autoSyncEnabled ? '已开启' : '已关闭',
                    onTap: () async {
                      await configStore
                          .setAutoSyncEnabled(!configStore.autoSyncEnabled);
                      setState(() {});
                    },
                  ),
                  _GlassMenuRow(
                    icon: Icons.restart_alt_rounded,
                    title: '重置同步游标并全量拉取',
                    onTap: () async {
                      await ref
                          .read(syncControllerProvider.notifier)
                          .resetCursorsAndResync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已重置游标并触发全量同步')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _GlassMenuRow extends StatelessWidget {
  const _GlassMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 21, color: tokens.textSecondary),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: tokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
