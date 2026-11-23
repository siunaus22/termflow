import 'package:flutter/material.dart';

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 7,
    this.showPercentage = true,
  });

  final double progress;
  final Color color;
  final double height;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: height,
              backgroundColor: color.withAlpha(36),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
