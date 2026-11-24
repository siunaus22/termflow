import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/google_brand_widgets.dart';

/// Google Material You 风格设置页：主题色板切换、多彩标签创建、Supabase 云端连接与账号同步
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _anonKeyController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newTagController = TextEditingController();

  String _selectedNewTagHex = AppTheme.tagPalette.first.$2;
  bool _connecting = false;
  bool _authLoading = false;
  bool _isSignUpMode = false;

  @override
  void initState() {
    super.initState();
    final store = ref.read(appConfigStoreProvider);
    _urlController = TextEditingController(text: store.supabaseUrl);
    _anonKeyController = TextEditingController(text: store.supabaseAnonKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnectSupabase() async {
    final url = _urlController.text.trim();
    final key = _anonKeyController.text.trim();
    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请同时填写 SUPABASE_URL 和 SUPABASE_ANON_KEY')),
      );
      return;
    }

    setState(() => _connecting = true);
    try {
      await ref
          .read(appConfigStoreProvider)
          .saveSupabaseConfig(url: url, anonKey: key);
      final ok = await ref
          .read(supabaseManagerProvider.notifier)
          .connect(url: url, anonKey: key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(ok ? 'Supabase 连接成功，现在可以登录并同步' : '连接失败，请检查 URL 与 Key'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效邮箱及至少 6 位密码')),
      );
      return;
    }

    setState(() => _authLoading = true);
    try {
      final mgr = ref.read(supabaseManagerProvider.notifier);
      final err = _isSignUpMode
          ? await mgr.signUp(email, password)
          : await mgr.signIn(email, password);
      if (mounted) {
        if (err != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('认证失败：$err')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isSignUpMode ? '注册成功（如开启邮箱验证请前往收件箱确认）' : '登录成功，正在同步云端数据...',
              ),
            ),
          );
          await ref.read(syncControllerProvider.notifier).syncNow();
        }
      }
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(supabaseManagerProvider);
    final syncState = ref.watch(syncControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeSeed = ref.watch(themeSeedProvider);
    final configStore = ref.watch(appConfigStoreProvider);
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            GoogleBrandLogo(size: 24),
            SizedBox(width: 10),
            Text('个性化与云端同步', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Material You 动态主题色板与明暗模式
              _SectionCard(
                icon: Icons.palette_rounded,
                accentColor: themeSeed.seedColor,
                title: 'Material You 色彩与外观',
                subtitle: '选择你喜欢的 Google 主题色板，全局界面会联动切换柔和色彩层次',
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: GoogleThemeSeed.values.map((seed) {
                      final selected = seed == themeSeed;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            ref.read(themeSeedProvider.notifier).setSeed(seed),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: seed.seedColor.withAlpha(selected ? 42 : 18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? seed.seedColor
                                  : seed.seedColor.withAlpha(60),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: seed.seedColor,
                                child: selected
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                seed.label,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: selected ? seed.seedColor : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('跟随系统'),
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
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Google Keep 风格多彩标签管理
              _SectionCard(
                icon: Icons.style_rounded,
                accentColor: AppTheme.googleGreen,
                title: '多彩标签分类',
                subtitle: '为不同标签赋予专属 Google 色彩，列表一目了然',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.tagPalette.map((item) {
                      final active = _selectedNewTagHex == item.$2;
                      return Tooltip(
                        message: item.$1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () =>
                              setState(() => _selectedNewTagHex = item.$2),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: item.$3,
                              shape: BoxShape.circle,
                              border: active
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: active
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagController,
                          decoration: const InputDecoration(
                            hintText: '输入新标签名称（如：科研 / 健身 / 英语）',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final name = _newTagController.text.trim();
                          if (name.isEmpty) return;
                          await ref.read(tagRepositoryProvider).createTag(
                                name: name,
                                colorHex: _selectedNewTagHex,
                              );
                          _newTagController.clear();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('创建标签'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final color = AppTheme.parseHex(tag.colorHex);
                      return InputChip(
                        label: Text(
                          tag.name,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: color.withAlpha(26),
                        side: BorderSide(color: color.withAlpha(80)),
                        deleteIconColor: color,
                        avatar: CircleAvatar(
                          backgroundColor: color,
                          radius: 6,
                        ),
                        onDeleted: () => ref
                            .read(tagRepositoryProvider)
                            .softDeleteTag(tag.id),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Supabase 云端连接配置
              _SectionCard(
                icon: Icons.cloud_sync_rounded,
                accentColor: AppTheme.googleBlue,
                title: 'Supabase 云端服务配置',
                subtitle: '离线优先：未配置时所有数据安全保存在本地 SQLite；填入后即可多端实时同步',
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'SUPABASE_URL',
                      hintText: 'https://your-project.supabase.co',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _anonKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'SUPABASE_ANON_KEY',
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _connecting ? null : _saveAndConnectSupabase,
                        icon: _connecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_done_rounded, size: 18),
                        label: const Text('保存并连接'),
                      ),
                      const SizedBox(width: 12),
                      if (authState.isInitialized)
                        Chip(
                          backgroundColor: AppTheme.googleGreen.withAlpha(28),
                          side: BorderSide.none,
                          avatar: const Icon(Icons.check_circle_rounded,
                              color: AppTheme.googleGreen, size: 16),
                          label: const Text(
                            '服务已连接',
                            style: TextStyle(
                              color: AppTheme.googleGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (authState.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authState.error!,
                      style: const TextStyle(
                        color: AppTheme.googleRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // 4. 账号认证与双向同步
              _SectionCard(
                icon: Icons.verified_user_rounded,
                accentColor: AppTheme.googlePurple,
                title: '账号与双向增量同步',
                subtitle: '基于 Last-Write-Wins (updated_at) + Realtime 实时推送',
                children: [
                  if (!authState.isInitialized)
                    Text(
                      '请先在上方填写并连接你的 Supabase 项目。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    )
                  else if (authState.isLoggedIn) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.googlePurple.withAlpha(32),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.googlePurple,
                        ),
                      ),
                      title: Text(
                        authState.user?.email ?? '已登录用户',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        syncState.lastSummary ?? '待推送变更：$pendingCount 条',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => ref
                            .read(supabaseManagerProvider.notifier)
                            .signOut(),
                        child: const Text('退出登录'),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '后台自动同步',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('网络恢复、Realtime 推送及定时自动同步'),
                      value: configStore.autoSyncEnabled,
                      onChanged: (v) async {
                        await configStore.setAutoSyncEnabled(v);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: syncState.phase == SyncUiPhase.syncing
                              ? null
                              : () async {
                                  final res = await ref
                                      .read(syncControllerProvider.notifier)
                                      .syncNow();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res.success
                                              ? '同步完成：拉取 ${res.pulledCount} 条，推送 ${res.pushedCount} 条'
                                              : '同步失败：${res.errorMessage}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('立即手动同步'),
                        ),
                        OutlinedButton.icon(
                          onPressed: syncState.phase == SyncUiPhase.syncing
                              ? null
                              : () => ref
                                  .read(syncControllerProvider.notifier)
                                  .resetCursorsAndResync(),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('重置游标全量拉取'),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '邮箱'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '密码（至少 6 位）'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _authLoading ? null : _submitAuth,
                          child: Text(_isSignUpMode ? '注册账号' : '登录并同步'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _isSignUpMode = !_isSignUpMode),
                          child: Text(_isSignUpMode ? '已有账号？去登录' : '没有账号？注册'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accentColor.withAlpha(32),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
