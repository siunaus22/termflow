import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/gemini_tokens.dart';

/// 1. 高帧率零离屏拷贝优化的 Gemini 半透明毛玻璃容器
/// 由于底层 GeminiAmbientBackground 本身即为大半径低频弥散极光，默认采用「半透明色调表面 + 微高光渐变层 + 1px 镜面描边」，
/// 避免在移动端滚动与手势退出时产生多层全屏 BackdropFilter 纹理回读卡顿；仅在确需覆盖高频文字时按需开启 enableBlur
class GeminiGlassCard extends StatelessWidget {
  const GeminiGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurSigma,
    this.backgroundColor,
    this.isHighlighted = false,
    this.enableBlur = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? blurSigma;
  final Color? backgroundColor;
  final bool isHighlighted;
  final bool enableBlur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final radius = borderRadius ?? BorderRadius.circular(tokens.cardRadius);
    final fill = backgroundColor ?? tokens.glassSurface;
    final topTint = Color.alphaBlend(
      Colors.white.withAlpha(tokens.isDark ? 10 : 55),
      fill,
    );

    Widget inner = AnimatedContainer(
      duration: GeminiTokens.fastDuration,
      curve: GeminiTokens.springCurve,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topTint, fill],
        ),
        borderRadius: radius,
        border: Border.all(
          color:
              isHighlighted ? tokens.glassHighlightBorder : tokens.glassBorder,
          width: isHighlighted ? 1.35 : 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      inner = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: inner,
        ),
      );
    }

    Widget result = enableBlur
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma ?? 12.0,
                sigmaY: blurSigma ?? 12.0,
              ),
              child: inner,
            ),
          )
        : inner;

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }
    return result;
  }
}

/// 2. Gemini 经典四角星芒（✦）组件：默认静态零开销，仅在聚焦或同步时启动微动效
class GeminiSparkleIcon extends StatefulWidget {
  const GeminiSparkleIcon({
    super.key,
    this.size = 22,
    this.animate = false,
    this.spin = false,
  });

  final double size;
  final bool animate;
  final bool spin;

  @override
  State<GeminiSparkleIcon> createState() => _GeminiSparkleIconState();
}

class _GeminiSparkleIconState extends State<GeminiSparkleIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  void _ensureController() {
    final shouldRun = widget.animate || widget.spin;
    if (shouldRun) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      if (!_ctrl!.isAnimating) {
        _ctrl!.repeat();
      }
    } else {
      _ctrl?.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureController();
  }

  @override
  void didUpdateWidget(covariant GeminiSparkleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureController();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || (!widget.animate && !widget.spin) || _ctrl == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const CustomPaint(painter: _GeminiStarPainter(phase: 0.2)),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, _) {
        final t = _ctrl!.value;
        final breathScale =
            widget.animate ? (0.92 + 0.12 * math.sin(t * math.pi * 2)) : 1.0;
        final angle = widget.spin
            ? t * math.pi * 2
            : 0.14 * math.sin(t * math.pi * 2);

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: breathScale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(painter: _GeminiStarPainter(phase: t)),
            ),
          ),
        );
      },
    );
  }
}

class _GeminiStarPainter extends CustomPainter {
  const _GeminiStarPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;
    final k = r * 0.16;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
      ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
      ..close();

    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: const [
        GeminiTokens.electricBlue,
        GeminiTokens.cobaltViolet,
        GeminiTokens.softViolet,
        GeminiTokens.roseAccent,
      ],
      begin: Alignment(
        -0.8 + 0.4 * math.cos(phase * math.pi * 2),
        -0.8 + 0.4 * math.sin(phase * math.pi * 2),
      ),
      end: const Alignment(0.9, 0.9),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GeminiStarPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// 3. 克制的 Gemini 蓝紫星云渐变标题
class GeminiGradientText extends StatelessWidget {
  const GeminiGradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => tokens.brandGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

/// 4. Gemini 核心输入胶囊栏（零离屏模糊拷贝，满帧响应键盘弹起与退出）
class GeminiPromptBar extends StatefulWidget {
  const GeminiPromptBar({
    super.key,
    required this.hintText,
    required this.onQuickSubmit,
    required this.onOpenFullEditor,
    required this.onFocusChanged,
    this.trailingActions = const [],
  });

  final String hintText;
  final Future<void> Function(String title) onQuickSubmit;
  final VoidCallback onOpenFullEditor;
  final ValueChanged<bool> onFocusChanged;
  final List<Widget> trailingActions;

  @override
  State<GeminiPromptBar> createState() => _GeminiPromptBarState();
}

class _GeminiPromptBarState extends State<GeminiPromptBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_isFocused != _focusNode.hasFocus) {
        setState(() => _isFocused = _focusNode.hasFocus);
        widget.onFocusChanged(_focusNode.hasFocus);
      }
    });
    _controller.addListener(() {
      final nonEmpty = _controller.text.trim().isNotEmpty;
      if (_hasText != nonEmpty) {
        setState(() => _hasText = nonEmpty);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    _controller.clear();
    await widget.onQuickSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    final radius = BorderRadius.circular(999);

    return AnimatedContainer(
      duration: GeminiTokens.mediumDuration,
      curve: GeminiTokens.springCurve,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: _isFocused ? tokens.subtleBorderGradient : null,
        color: _isFocused ? null : tokens.glassBorder,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.glassElevated,
          borderRadius: radius,
        ),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
            child: Row(
              children: [
                GeminiSparkleIcon(
                  size: 22,
                  animate: _isFocused || _hasText,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSubmit(),
                    style: TextStyle(
                      fontSize: 15.5,
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: 15.5,
                        color: tokens.textSecondary,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (_hasText)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: GeminiTokens.cobaltViolet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: _handleSubmit,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 18),
                          SizedBox(width: 4),
                          Text('添加'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: '打开完整新建面板',
                    onPressed: widget.onOpenFullEditor,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: tokens.textSecondary,
                    ),
                  ),
                  ...widget.trailingActions,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5. 轻量光波骨架屏
class GeminiShimmerSkeleton extends StatefulWidget {
  const GeminiShimmerSkeleton({
    super.key,
    this.height = 68,
    this.borderRadius = 22,
  });

  final double height;
  final double borderRadius;

  @override
  State<GeminiShimmerSkeleton> createState() => _GeminiShimmerSkeletonState();
}

class _GeminiShimmerSkeletonState extends State<GeminiShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GeminiTokens.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pos = -1.0 + 3.0 * _ctrl.value;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: tokens.glassBorder),
            gradient: LinearGradient(
              begin: Alignment(pos - 0.8, 0),
              end: Alignment(pos + 0.8, 0),
              colors: [
                tokens.glassSurface,
                GeminiTokens.cobaltViolet.withAlpha(tokens.isDark ? 38 : 24),
                tokens.glassSurface,
              ],
            ),
          ),
        );
      },
    );
  }
}
