import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/gemini_tokens.dart';
import 'gemini_components.dart';

/// 1. Gemini 四芒星新建图标（静态零开销）
class GooglePlusIcon extends StatelessWidget {
  const GooglePlusIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return GeminiSparkleIcon(size: size);
  }
}

/// 2. Gemini 星云流光光环头像（蓝 -> 钴紫 -> 紫罗兰 -> 柔玫红）
class GoogleRingAvatar extends StatelessWidget {
  const GoogleRingAvatar({
    super.key,
    required this.text,
    this.size = 34,
    this.ringWidth = 2.2,
    this.fillColor = const Color(0xFF282D3E),
    this.showCameraBadge = false,
  });

  final String text;
  final double size;
  final double ringWidth;
  final Color fillColor;
  final bool showCameraBadge;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final displayText =
        text.trim().isEmpty ? 'TF' : text.trim().characters.take(2).toString();
    final innerSize = size - ringWidth * 3.4;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GeminiAvatarRingPainter(strokeWidth: ringWidth),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF33416E), Color(0xFF4A386B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: tokens.glassBorder, width: 0.8),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                color: Colors.white,
                fontSize: innerSize * (displayText.length > 1 ? 0.36 : 0.46),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
          if (showCameraBadge)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: size * 0.30,
                height: size * 0.30,
                decoration: BoxDecoration(
                  color: tokens.glassElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.glassBorder),
                ),
                child: const Center(
                  child: GeminiSparkleIcon(size: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeminiAvatarRingPainter extends CustomPainter {
  _GeminiAvatarRingPainter({required this.strokeWidth});

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    const sweepGradient = SweepGradient(
      colors: [
        GeminiTokens.electricBlue,
        GeminiTokens.cobaltViolet,
        GeminiTokens.softViolet,
        GeminiTokens.roseAccent,
        GeminiTokens.cyanAccent,
        GeminiTokens.electricBlue,
      ],
    );

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = sweepGradient.createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 2, false, p);
  }

  @override
  bool shouldRepaint(covariant _GeminiAvatarRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}

/// 3. Material 3 × Gemini 柔和光晕圆章
class M3ScallopBadge extends StatelessWidget {
  const M3ScallopBadge({
    super.key,
    required this.child,
    this.size = 46,
    this.color,
    this.lobes = 8,
  });

  final Widget child;
  final double size;
  final Color? color;
  final int lobes;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final badgeColor = color ?? tokens.glassPill;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScallopPainter(
          color: badgeColor,
          borderColor: tokens.glassBorder,
          lobes: lobes,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ScallopPainter extends CustomPainter {
  _ScallopPainter({
    required this.color,
    required this.borderColor,
    required this.lobes,
  });

  final Color color;
  final Color borderColor;
  final int lobes;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = size.width * 0.44;
    final amp = size.width * 0.042;
    const steps = 100;

    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * math.pi * 2;
      final r = baseR + amp * math.cos(lobes * theta);
      final x = cx + r * math.cos(theta);
      final y = cy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ScallopPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}

/// 4. 毛玻璃分段岛式容器组（外圈 24px 大圆角 + 内缝 4px + 毛玻璃模糊与微光描边）
class M3SegmentedColumn extends StatelessWidget {
  const M3SegmentedColumn({
    super.key,
    required this.children,
    this.outerRadius = 24,
    this.innerRadius = 5,
    this.gap = 3.0,
    this.tileColor,
  });

  final List<Widget> children;
  final double outerRadius;
  final double innerRadius;
  final double gap;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final tokens = GeminiTokens.of(context);
    final bg = tileColor ?? tokens.glassSurface;
    final count = children.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isFirst = i == 0;
        final isLast = i == count - 1;
        final radius = BorderRadius.only(
          topLeft: Radius.circular(isFirst ? outerRadius : innerRadius),
          topRight: Radius.circular(isFirst ? outerRadius : innerRadius),
          bottomLeft: Radius.circular(isLast ? outerRadius : innerRadius),
          bottomRight: Radius.circular(isLast ? outerRadius : innerRadius),
        );

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : gap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: tokens.glassBorder, width: 1),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: children[i],
            ),
          ),
        );
      }),
    );
  }
}

/// 5. 胶囊教学周徽章
class ChromeCounterBadge extends StatelessWidget {
  const ChromeCounterBadge({
    super.key,
    required this.text,
    this.onTap,
    this.tooltip,
  });

  final String text;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.glassPill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.glassBorder),
      ),
      child: Text(
        'W$text',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
          height: 1.0,
        ),
      ),
    );

    if (onTap == null) return pill;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: pill,
        ),
      ),
    );
  }
}

/// 6. Gemini 四芒星品牌徽标（静态零开销）
class GoogleBrandLogo extends StatelessWidget {
  const GoogleBrandLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return GeminiSparkleIcon(size: size);
  }
}

class GoogleFourColorBar extends StatelessWidget {
  const GoogleFourColorBar({super.key, this.height = 3});

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        gradient: tokens.brandGradient,
      ),
    );
  }
}

class GoogleProgressRing extends StatelessWidget {
  const GoogleProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 6,
    this.centerChild,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? centerChild;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GeminiRingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              trackColor: tokens.glassBorder,
            ),
          ),
          if (centerChild != null) centerChild!,
        ],
      ),
    );
  }
}

class _GeminiRingPainter extends CustomPainter {
  _GeminiRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    if (progress <= 0.001) return;

    const gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [
        GeminiTokens.electricBlue,
        GeminiTokens.cobaltViolet,
        GeminiTokens.softViolet,
        GeminiTokens.cyanAccent,
        GeminiTokens.electricBlue,
      ],
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GeminiRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trackColor != trackColor;
}
