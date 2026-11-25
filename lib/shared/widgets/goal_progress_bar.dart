import 'package:flutter/material.dart';

import '../../core/theme/gemini_tokens.dart';

/// Gemini 顺滑阻尼进度条
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
    this.showPercentage = true,
  });

  final double progress;
  final Color color;
  final double height;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: clamped),
              duration: GeminiTokens.mediumDuration,
              curve: GeminiTokens.springCurve,
              builder: (context, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: height,
                backgroundColor: tokens.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(width: 10),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
