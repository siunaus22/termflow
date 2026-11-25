import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/gemini_tokens.dart';
import '../providers/app_providers.dart';

/// Google Gemini App 原生级流体极光与边缘呼吸背景组件
/// - 底层强制采用编译期硬件加速 GLSL Fragment Shader (shaders/gemini_fluid.frag)
/// - Idle 待机态：18s~26s 有机轨迹低透明度弥散漂移
/// - Active 唤醒态：聚焦输入栏或同步运算时，光晕向焦点聚拢并平缓提升流速与边缘泛光
/// - 无障碍支持：自动响应系统 disableAnimations 与应用内动态背景开关，平滑降级为静态极光帧
class GeminiAmbientBackground extends ConsumerStatefulWidget {
  const GeminiAmbientBackground({super.key});

  @override
  ConsumerState<GeminiAmbientBackground> createState() =>
      _GeminiAmbientBackgroundState();
}

class _GeminiAmbientBackgroundState
    extends ConsumerState<GeminiAmbientBackground>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  final ValueNotifier<int> _frameTick = ValueNotifier<int>(0);

  Duration _lastElapsed = Duration.zero;
  double _phase = 1.8; // 初始优雅构图相位
  double _smoothActivity = 0.0;
  double _smoothDark = 1.0;
  Offset _smoothFocus = const Offset(0.5, 0.30);

  bool _targetActive = false;
  bool _targetDark = true;
  Offset _targetFocus = const Offset(0.5, 0.30);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _programFuture ??=
          ui.FragmentProgram.fromAsset('shaders/gemini_fluid.frag');
      final program = await _programFuture!;
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
      });
      _syncTickerState();
    } catch (_) {
      // 着色器加载异常时优雅回退至静态柔和渐变基底
    }
  }

  void _onTick(Duration elapsed) {
    final dtRaw = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final dt = dtRaw.clamp(0.0, 0.05);

    // 阻尼插值过渡：Idle <-> Active 与 Dark <-> Light 丝滑无突变
    final alpha = 1.0 - math.exp(-dt * 3.8);
    _smoothActivity += ((_targetActive ? 1.0 : 0.0) - _smoothActivity) * alpha;
    _smoothDark += ((_targetDark ? 1.0 : 0.0) - _smoothDark) * alpha;
    _smoothFocus = Offset.lerp(_smoothFocus, _targetFocus, alpha)!;

    // 连续相位积分：待机周期约 22 秒，唤醒态平滑提速且绝不跳帧
    final angularVelocity = 0.28 + 0.56 * _smoothActivity;
    _phase = (_phase + dt * angularVelocity) % (math.pi * 200.0);

    _frameTick.value++;
  }

  void _syncTickerState() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final motionEnabled = ref.read(ambientMotionProvider);
    final shouldAnimate = !reduceMotion && motionEnabled && _shader != null;

    if (shouldAnimate && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!shouldAnimate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frameTick.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = ref.watch(geminiActivityProvider);
    final focusPoint = ref.watch(geminiFocusPointProvider);
    final motionEnabled = ref.watch(ambientMotionProvider);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    _targetDark = isDark;
    _targetActive = isActive;
    _targetFocus = focusPoint;

    if (reduceMotion || !motionEnabled) {
      _smoothDark = isDark ? 1.0 : 0.0;
      _smoothActivity = isActive ? 0.6 : 0.0;
      _smoothFocus = focusPoint;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTickerState());

    final shader = _shader;
    if (shader == null) {
      final tokens = GeminiTokens.of(context);
      return ColoredBox(color: tokens.baseCanvas);
    }

    // RepaintBoundary 严格隔离重绘区域，确保背景 60/120fps 动画对上层 UI 零开销
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GeminiFluidShaderPainter(
          shader: shader,
          repaint: _frameTick,
          getPhase: () => _phase,
          getActivity: () => _smoothActivity,
          getDark: () => _smoothDark,
          getFocus: () => _smoothFocus,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GeminiFluidShaderPainter extends CustomPainter {
  _GeminiFluidShaderPainter({
    required this.shader,
    required Listenable repaint,
    required this.getPhase,
    required this.getActivity,
    required this.getDark,
    required this.getFocus,
  }) : super(repaint: repaint);

  final ui.FragmentShader shader;
  final double Function() getPhase;
  final double Function() getActivity;
  final double Function() getDark;
  final Offset Function() getFocus;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final focus = getFocus();

    // 严格对应 shaders/gemini_fluid.frag 的 uniform 顺序 [0..6]
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, getPhase())
      ..setFloat(3, getActivity())
      ..setFloat(4, getDark())
      ..setFloat(5, focus.dx)
      ..setFloat(6, focus.dy);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GeminiFluidShaderPainter oldDelegate) =>
      oldDelegate.shader != shader;
}
