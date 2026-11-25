import 'package:flutter/material.dart';

import '../constants/app_enums.dart';
import 'gemini_tokens.dart';

/// Material 3 × Google Gemini App 主题构建器
/// 通过透明 Scaffold 画布让底层 GLSL 流体背景自然透出，配合 GeminiTokens 毛玻璃表面与高对比字阶
class AppTheme {
  AppTheme._();

  // 核心色彩别名（兼容业务组件引用）
  static const Color googleBlue = GeminiTokens.electricBlue;
  static const Color googleRed = GeminiTokens.roseAccent;
  static const Color googleYellow = Color(0xFFF5B945);
  static const Color googleGreen = GeminiTokens.mintSuccess;
  static const Color googlePurple = GeminiTokens.softViolet;
  static const Color googleTeal = GeminiTokens.cyanAccent;

  static const List<(String name, String hex, Color color)> tagPalette = [
    ('电光蓝', '#4285F4', GeminiTokens.electricBlue),
    ('钴蓝紫', '#6B7CFF', GeminiTokens.cobaltViolet),
    ('紫罗兰', '#9B72CB', GeminiTokens.softViolet),
    ('冰川青', '#4FACFE', GeminiTokens.cyanAccent),
    ('星芒玫红', '#D96570', GeminiTokens.roseAccent),
    ('雾凇绿', '#5BB98C', GeminiTokens.mintSuccess),
    ('流金琥珀', '#E8A23A', Color(0xFFE8A23A)),
    ('极夜靛青', '#5C6BC0', Color(0xFF5C6BC0)),
  ];

  static Color parseHex(String hex, {Color fallback = googleBlue}) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
    return fallback;
  }

  static Color tonalContainer(
    BuildContext context,
    Color accent, {
    int lightAlpha = 24,
    int darkAlpha = 36,
  }) {
    final tokens = GeminiTokens.of(context);
    return Color.alphaBlend(
      accent.withAlpha(tokens.isDark ? darkAlpha : lightAlpha),
      tokens.glassSurface,
    );
  }

  static ThemeData light({Color? seedColor}) {
    final seed = seedColor ?? GoogleThemeSeed.geminiAurora.seedColor;
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    const tokens = GeminiTokens.light;
    final scheme = base.copyWith(
      primary: const Color(0xFF1A73E8),
      secondary: GeminiTokens.cobaltViolet,
      tertiary: GeminiTokens.softViolet,
      surface: tokens.baseCanvas,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      surfaceContainerLowest: const Color(0xD9FFFFFF),
      surfaceContainerLow: const Color(0xC7F4F7FC),
      surfaceContainer: tokens.glassSurface,
      surfaceContainerHigh: tokens.glassPill,
      surfaceContainerHighest: const Color(0xDDE2EAF6),
      secondaryContainer: const Color(0x304285F4),
      onSecondaryContainer: const Color(0xFF174EA6),
      outline: const Color(0x330F172A),
      outlineVariant: tokens.glassBorder,
    );

    return _buildTheme(scheme, Brightness.light, tokens);
  }

  static ThemeData dark({Color? seedColor}) {
    final seed = seedColor ?? GoogleThemeSeed.geminiAurora.seedColor;
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    const tokens = GeminiTokens.dark;
    final scheme = base.copyWith(
      primary: const Color(0xFF8AB4F8),
      secondary: const Color(0xFFA8B5FF),
      tertiary: const Color(0xFFC59BF0),
      surface: tokens.baseCanvas,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      surfaceContainerLowest: const Color(0xB818191D),
      surfaceContainerLow: const Color(0xAD1A1B20),
      surfaceContainer: tokens.glassSurface,
      surfaceContainerHigh: tokens.glassPill,
      surfaceContainerHighest: const Color(0xCC303440),
      secondaryContainer: const Color(0x3D6B7CFF),
      onSecondaryContainer: const Color(0xFFDCE4FF),
      outline: const Color(0x38FFFFFF),
      outlineVariant: tokens.glassBorder,
    );

    return _buildTheme(scheme, Brightness.dark, tokens);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness,
    GeminiTokens tokens,
  ) {
    final baseText = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final textTheme = baseText
        .apply(
          bodyColor: tokens.textPrimary,
          displayColor: tokens.textPrimary,
          fontFamilyFallback: GeminiTokens.fontFallback,
        )
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
            height: 1.18,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          headlineSmall: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          titleMedium: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          bodyLarge: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: tokens.textPrimary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
          bodySmall: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: tokens.textSecondary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      // Scaffold 默认透明，使根层 GeminiAmbientBackground 的液态极光自然透出
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: tokens.glassSurface,
      dividerColor: tokens.glassBorder,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 58,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.glassSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.glassBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.isDark
            ? const Color(0xEB1B1C21)
            : const Color(0xF2FFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.heroRadius),
          side: BorderSide(color: tokens.glassBorder, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.isDark
            ? const Color(0xEB18191E)
            : const Color(0xF2F8FAFD),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: tokens.glassBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.glassPill,
        hintStyle: TextStyle(color: tokens.textSecondary, fontSize: 14.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: tokens.glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: tokens.glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide:
              BorderSide(color: tokens.glassHighlightBorder, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.glassPill,
        shape: const StadiumBorder(),
        side: BorderSide(color: tokens.glassBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.glassBorder, width: 1),
          backgroundColor: tokens.glassSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamilyFallback: GeminiTokens.fontFallback,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.glassElevated,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? tokens.textPrimary : tokens.textSecondary,
            fontFamilyFallback: GeminiTokens.fontFallback,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            tokens.isDark ? const Color(0xF0252730) : const Color(0xF01E222B),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: const StadiumBorder(),
      ),
    );
  }
}
