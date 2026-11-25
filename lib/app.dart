import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/gemini_ambient_background.dart';

class TermFlowApp extends ConsumerWidget {
  const TermFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeSeed = ref.watch(themeSeedProvider);

    return MaterialApp(
      title: 'TermFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seedColor: themeSeed.seedColor),
      darkTheme: AppTheme.dark(seedColor: themeSeed.seedColor),
      themeMode: themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 全局持久底层渲染原生 GLSL 液态极光背景，页面切换与弹窗呼出时无缝透光不重置相位
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            const GeminiAmbientBackground(),
            if (child != null) child,
          ],
        );
      },
      home: const AppShell(),
    );
  }
}
