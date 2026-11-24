import 'package:flutter/material.dart';

/// Google Material You (Material 3 Expressive) 主题引擎
/// 融合 Google 四原色、柔和色彩容器（Tonal Surfaces）、大圆角胶囊形态与动态种子色系统
class AppTheme {
  AppTheme._();

  // Google 经典四原色
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC04);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googlePurple = Color(0xFF9334E6);
  static const Color googleTeal = Color(0xFF12B5CB);

  static const List<Color> googleBrandColors = [
    googleBlue,
    googleRed,
    googleYellow,
    googleGreen,
  ];

  /// 供自定义标签选择的多彩 Google Keep / Calendar 调色盘
  static const List<(String name, String hex, Color color)> tagPalette = [
    ('海湾蓝', '#1A73E8', Color(0xFF1A73E8)),
    ('珊瑚红', '#EA4335', Color(0xFFEA4335)),
    ('向日葵黄', '#F9AB00', Color(0xFFF9AB00)),
    ('翡翠绿', '#34A853', Color(0xFF34A853)),
    ('鸢尾紫', '#9334E6', Color(0xFF9334E6)),
    ('湖水青', '#12B5CB', Color(0xFF12B5CB)),
    ('蜜桃橙', '#FA7B17', Color(0xFFFA7B17)),
    ('莓果粉', '#E52592', Color(0xFFE52592)),
  ];

  static Color parseHex(String hex, {Color fallback = googleBlue}) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) {
        // 将旧版冷灰蓝色标签自动映射为更明快的 Google 蓝
        if (cleaned.toUpperCase() == '4F6BED') return const Color(0xFF1A73E8);
        if (cleaned.toUpperCase() == '64748B') return const Color(0xFF12B5CB);
        return Color(value);
      }
    }
    return fallback;
  }

  /// 根据目标/标签主色生成柔和的 Material You 浅色/深色容器底色
  static Color tonalContainer(
    BuildContext context,
    Color accent, {
    int lightAlpha = 26,
    int darkAlpha = 44,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Color.alphaBlend(
      accent.withAlpha(isDark ? darkAlpha : lightAlpha),
      Theme.of(context).colorScheme.surfaceContainerLowest,
    );
  }

  static ThemeData light({Color seedColor = const Color(0xFF1A73E8)}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final tintedCanvas = Color.alphaBlend(
      scheme.primary.withAlpha(12),
      const Color(0xFFF8FAFD),
    );
    final sidebarBg = Color.alphaBlend(
      scheme.primary.withAlpha(20),
      const Color(0xFFF1F5FB),
    );

    final colorScheme = scheme.copyWith(
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: tintedCanvas,
      surfaceContainer: sidebarBg,
    );

    return _buildTheme(colorScheme, Brightness.light, tintedCanvas);
  }

  static ThemeData dark({Color seedColor = const Color(0xFF1A73E8)}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    final darkCanvas = Color.alphaBlend(
      scheme.primary.withAlpha(14),
      const Color(0xFF111318),
    );
    final darkCard = Color.alphaBlend(
      scheme.primary.withAlpha(20),
      const Color(0xFF1A1D24),
    );
    final darkSidebar = Color.alphaBlend(
      scheme.primary.withAlpha(26),
      const Color(0xFF151820),
    );

    final colorScheme = scheme.copyWith(
      surface: darkCard,
      surfaceContainerLowest: darkCard,
      surfaceContainerLow: darkCanvas,
      surfaceContainer: darkSidebar,
    );

    return _buildTheme(colorScheme, Brightness.dark, darkCanvas);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness,
    Color scaffoldBg,
  ) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: colorScheme.surfaceContainerLowest,
      dividerColor: colorScheme.outlineVariant.withAlpha(isDark ? 90 : 120),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.alphaBlend(
          colorScheme.primary.withAlpha(isDark ? 26 : 16),
          colorScheme.surfaceContainerLowest,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(90)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
