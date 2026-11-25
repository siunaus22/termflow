import 'package:flutter/material.dart';

/// 解耦的 Google Gemini App 全局 Design Tokens
/// 统一收口色彩、毛玻璃参数、圆角尺度、阻尼缓动曲线与克制渐变定义
@immutable
class GeminiTokens extends ThemeExtension<GeminiTokens> {
  const GeminiTokens({
    required this.isDark,
    required this.baseCanvas,
    required this.glassSurface,
    required this.glassElevated,
    required this.glassPill,
    required this.glassBorder,
    required this.glassHighlightBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.blurSigma,
    required this.cardRadius,
    required this.heroRadius,
    required this.brandGradient,
    required this.subtleBorderGradient,
  });

  final bool isDark;
  final Color baseCanvas;
  final Color glassSurface;
  final Color glassElevated;
  final Color glassPill;
  final Color glassBorder;
  final Color glassHighlightBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final double blurSigma;
  final double cardRadius;
  final double heroRadius;
  final LinearGradient brandGradient;
  final LinearGradient subtleBorderGradient;

  // Gemini 核心色谱常量
  static const Color electricBlue = Color(0xFF4285F4);
  static const Color cobaltViolet = Color(0xFF6B7CFF);
  static const Color softViolet = Color(0xFF9B72CB);
  static const Color cyanAccent = Color(0xFF4FACFE);
  static const Color roseAccent = Color(0xFFD96570);
  static const Color mintSuccess = Color(0xFF5BB98C);

  // 全局统一阻尼缓动曲线 cubic-bezier(0.22, 1, 0.36, 1)
  static const Curve springCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Duration fastDuration = Duration(milliseconds: 220);
  static const Duration mediumDuration = Duration(milliseconds: 380);

  // 现代无衬线字体回退栈
  static const List<String> fontFallback = [
    'Google Sans',
    'Inter',
    'Segoe UI Variable Display',
    'Segoe UI',
    'PingFang SC',
    'Microsoft YaHei UI',
    'Noto Sans SC',
    'sans-serif',
  ];

  static const GeminiTokens dark = GeminiTokens(
    isDark: true,
    baseCanvas: Color(0xFF101013), // #0E0E10 ~ #131314
    glassSurface: Color(0xAD1C1D20), // rgba(28, 29, 32, 0.68)
    glassElevated: Color(0xBD24262C), // rgba(36, 38, 44, 0.74)
    glassPill: Color(0xB82A2D36), // 胶囊悬浮态
    glassBorder: Color(0x16FFFFFF), // rgba(255, 255, 255, 0.086)
    glassHighlightBorder: Color(0x528AB4F8),
    textPrimary: Color(0xFFF2F4F8), // WCAG AAA (>14:1)
    textSecondary: Color(0xFFA8B0C3), // WCAG AA+ (>7.2:1)
    textMuted: Color(0xFF7D869B),
    blurSigma: 24.0,
    cardRadius: 24.0,
    heroRadius: 28.0,
    brandGradient: LinearGradient(
      colors: [electricBlue, cobaltViolet, softViolet, roseAccent],
      stops: [0.0, 0.38, 0.74, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    subtleBorderGradient: LinearGradient(
      colors: [
        Color(0x884285F4),
        Color(0x886B7CFF),
        Color(0x889B72CB),
        Color(0x664FACFE),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const GeminiTokens light = GeminiTokens(
    isDark: false,
    baseCanvas: Color(0xFFF8FAFD),
    glassSurface: Color(0xBDFFFFFF), // rgba(255, 255, 255, 0.74)
    glassElevated: Color(0xD6FFFFFF), // rgba(255, 255, 255, 0.84)
    glassPill: Color(0xCCEBF1FA),
    glassBorder: Color(0x140F172A), // rgba(15, 23, 42, 0.078)
    glassHighlightBorder: Color(0x664285F4),
    textPrimary: Color(0xFF11151F), // WCAG AAA (>15:1)
    textSecondary: Color(0xFF4A5468), // WCAG AA+ (>6.8:1)
    textMuted: Color(0xFF717C92),
    blurSigma: 24.0,
    cardRadius: 24.0,
    heroRadius: 28.0,
    brandGradient: LinearGradient(
      colors: [
        Color(0xFF1A73E8),
        Color(0xFF5C6BC0),
        Color(0xFF8E54E9),
        Color(0xFFD9536F),
      ],
      stops: [0.0, 0.38, 0.74, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    subtleBorderGradient: LinearGradient(
      colors: [
        Color(0x774285F4),
        Color(0x776B7CFF),
        Color(0x779B72CB),
        Color(0x554FACFE),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static GeminiTokens of(BuildContext context) =>
      Theme.of(context).extension<GeminiTokens>() ?? dark;

  @override
  GeminiTokens copyWith({
    bool? isDark,
    Color? baseCanvas,
    Color? glassSurface,
    Color? glassElevated,
    Color? glassPill,
    Color? glassBorder,
    Color? glassHighlightBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    double? blurSigma,
    double? cardRadius,
    double? heroRadius,
    LinearGradient? brandGradient,
    LinearGradient? subtleBorderGradient,
  }) {
    return GeminiTokens(
      isDark: isDark ?? this.isDark,
      baseCanvas: baseCanvas ?? this.baseCanvas,
      glassSurface: glassSurface ?? this.glassSurface,
      glassElevated: glassElevated ?? this.glassElevated,
      glassPill: glassPill ?? this.glassPill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlightBorder: glassHighlightBorder ?? this.glassHighlightBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      blurSigma: blurSigma ?? this.blurSigma,
      cardRadius: cardRadius ?? this.cardRadius,
      heroRadius: heroRadius ?? this.heroRadius,
      brandGradient: brandGradient ?? this.brandGradient,
      subtleBorderGradient: subtleBorderGradient ?? this.subtleBorderGradient,
    );
  }

  @override
  GeminiTokens lerp(ThemeExtension<GeminiTokens>? other, double t) {
    if (other is! GeminiTokens) return this;
    return GeminiTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      baseCanvas: Color.lerp(baseCanvas, other.baseCanvas, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassElevated: Color.lerp(glassElevated, other.glassElevated, t)!,
      glassPill: Color.lerp(glassPill, other.glassPill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlightBorder:
          Color.lerp(glassHighlightBorder, other.glassHighlightBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      heroRadius: heroRadius + (other.heroRadius - heroRadius) * t,
      brandGradient: LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      subtleBorderGradient: LinearGradient.lerp(
        subtleBorderGradient,
        other.subtleBorderGradient,
        t,
      )!,
    );
  }
}
