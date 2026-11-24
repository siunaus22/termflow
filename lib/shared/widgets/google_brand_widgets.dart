import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Google Calendar / Google Tasks / Google Drive 标志性的四色「+」号图标
class GooglePlusIcon extends StatelessWidget {
  const GooglePlusIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GooglePlusPainter(),
      ),
    );
  }
}

class _GooglePlusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final arm = size.width * 0.40;
    final stroke = size.width * 0.17;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // 上臂：Google Red
    paint.color = AppTheme.googleRed;
    canvas.drawLine(c, Offset(c.dx, c.dy - arm), paint);

    // 左臂：Google Yellow
    paint.color = AppTheme.googleYellow;
    canvas.drawLine(c, Offset(c.dx - arm, c.dy), paint);

    // 下臂：Google Green
    paint.color = AppTheme.googleGreen;
    canvas.drawLine(c, Offset(c.dx, c.dy + arm), paint);

    // 右臂：Google Blue（最后绘制覆盖中心交汇点）
    paint.color = AppTheme.googleBlue;
    canvas.drawLine(c, Offset(c.dx + arm, c.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google 四色几何品牌徽章（蓝、红、黄、绿四叶圆角矩阵）
class GoogleBrandLogo extends StatelessWidget {
  const GoogleBrandLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.43;
    final gap = size * 0.10;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Petal(
                size: dot,
                color: AppTheme.googleBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(dot * 0.55),
                  topRight: Radius.circular(dot * 0.55),
                  bottomLeft: Radius.circular(dot * 0.55),
                  bottomRight: Radius.circular(dot * 0.18),
                ),
              ),
              SizedBox(width: gap),
              _Petal(
                size: dot,
                color: AppTheme.googleRed,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(dot * 0.55),
                  topRight: Radius.circular(dot * 0.55),
                  bottomRight: Radius.circular(dot * 0.55),
                  bottomLeft: Radius.circular(dot * 0.18),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Petal(
                size: dot,
                color: AppTheme.googleYellow,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(dot * 0.55),
                  bottomLeft: Radius.circular(dot * 0.55),
                  bottomRight: Radius.circular(dot * 0.55),
                  topRight: Radius.circular(dot * 0.18),
                ),
              ),
              SizedBox(width: gap),
              _Petal(
                size: dot,
                color: AppTheme.googleGreen,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(dot * 0.55),
                  bottomLeft: Radius.circular(dot * 0.55),
                  bottomRight: Radius.circular(dot * 0.55),
                  topLeft: Radius.circular(dot * 0.18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Petal extends StatelessWidget {
  const _Petal({
    required this.size,
    required this.color,
    required this.borderRadius,
  });

  final double size;
  final Color color;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Google 标志性四色装饰条
class GoogleFourColorBar extends StatelessWidget {
  const GoogleFourColorBar({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: const Row(
          children: [
            Expanded(flex: 35, child: ColoredBox(color: AppTheme.googleBlue)),
            Expanded(flex: 22, child: ColoredBox(color: AppTheme.googleRed)),
            Expanded(flex: 18, child: ColoredBox(color: AppTheme.googleYellow)),
            Expanded(flex: 25, child: ColoredBox(color: AppTheme.googleGreen)),
          ],
        ),
      ),
    );
  }
}

/// Google Fit / Digital Wellbeing 风格的多彩圆环完成度指示器
class GoogleProgressRing extends StatelessWidget {
  const GoogleProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 7,
    this.centerChild,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? centerChild;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GoogleRingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              trackColor:
                  Theme.of(context).colorScheme.onSurface.withAlpha(24),
            ),
          ),
          if (centerChild != null) centerChild!,
        ],
      ),
    );
  }
}

class _GoogleRingPainter extends CustomPainter {
  _GoogleRingPainter({
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

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0.001) return;

    final sweep = math.pi * 2 * progress;
    const segments = [
      (0.0, 0.35, AppTheme.googleBlue),
      (0.35, 0.58, AppTheme.googleRed),
      (0.58, 0.78, AppTheme.googleYellow),
      (0.78, 1.0, AppTheme.googleGreen),
    ];

    for (final seg in segments) {
      if (progress <= seg.$1) break;
      final segStart = seg.$1;
      final segEnd = math.min(progress, seg.$2);
      final startAngle = -math.pi / 2 + math.pi * 2 * segStart;
      final segSweep = math.pi * 2 * (segEnd - segStart);
      if (segSweep <= 0) continue;

      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = seg.$3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, math.min(segSweep, sweep), false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _GoogleRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trackColor != trackColor;
}
