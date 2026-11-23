import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

/// 设置页：自定义 SUPABASE_URL / ANON_KEY、云端账号登录/注册、手动/自动同步、浅深色主题、标签管理
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
            content: Text(ok ? 'Supabase 连接成功，现在可以登录并同步' : '连接失败，请检查 URL 与 Key'),
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
    final configStore = ref.watch(appConfigStoreProvider);
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? [];
    final pendingCount = ref.watch(pendingChangeCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('设置与云端同步')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Supabase 连接配置
              _SectionCard(
                title: '1. Supabase 云端配置',
                subtitle: '离线优先：未配置时所有数据保存在本地 SQLite；填入后即可开启多端同步',
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_done_outlined, size: 18),
                        label: const Text('保存并连接'),
                      ),
                      const SizedBox(width: 12),
                      if (authState.isInitialized)
                        const Chip(
                          avatar: Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          label: Text('服务已连接'),
                        ),
                    ],
                  ),
                  if (authState.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authState.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // 2. 账号认证与同步控制
              _SectionCard(
                title: '2. 账号与双向同步',
                subtitle: '采用 Last-Write-Wins (updated_at) + 软删除增量同步策略',
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
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(authState.user?.email ?? '已登录用户'),
                      subtitle: Text(
                        syncState.lastSummary ??
                            '待推送变更：$pendingCount 条',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () =>
                            ref.read(supabaseManagerProvider.notifier).signOut(),
                        child: const Text('退出登录'),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('后台自动同步'),
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
              const SizedBox(height: 16),

              // 3. 外观主题（浅色/深色自动切换）
              _SectionCard(
                title: '3. 外观主题',
                subtitle: '支持跟随系统自动切换浅色 / 深色模式',
                children: [
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('跟随系统'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
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

              // 4. 标签管理
              _SectionCard(
                title: '4. 标签分类管理',
                subtitle: '自定义日计划标签（如：课程 / 项目 / 竞赛 / 生活）',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagController,
                          decoration: const InputDecoration(
                            hintText: '输入新标签名称...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () async {
                          final name = _newTagController.text.trim();
                          if (name.isEmpty) return;
                          await ref
                              .read(tagRepositoryProvider)
                              .createTag(name: name, colorHex: '#4F6BED');
                          _newTagController.clear();
                        },
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final color = AppTheme.parseHex(tag.colorHex);
                      return InputChip(
                        label: Text(tag.name),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
