#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniform layout:
// [0, 1] uSize       : viewport width, height
// [2]    uPhase      : integrated continuous fluid phase
// [3]    uActivity   : 0.0 = Idle, 1.0 = Active / Focus / Syncing
// [4]    uDarkMode   : 1.0 = Dark (#0E0E10~#131314), 0.0 = Light (#F8FAFD)
// [5, 6] uFocus      : normalized [0..1] focal point
uniform vec2 uSize;
uniform float uPhase;
uniform float uActivity;
uniform float uDarkMode;
uniform vec2 uFocus;

out vec4 fragColor;

vec3 mod289_3(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289_2(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289_3(((x * 34.0) + 10.0) * x);
}

// Fast 2D Simplex Noise (mobile GPU ALU friendly)
float snoise(vec2 v) {
  const vec4 C = vec4(
    0.211324865405187,
    0.366025403784439,
   -0.577350269189626,
    0.024390243902439
  );

  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);

  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

  i = mod289_2(i);
  vec3 p = permute(
    permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0)
  );

  vec3 m = max(
    0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)),
    0.0
  );
  m = m * m;
  m = m * m;

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

// Fast algebraic smooth plume (replaces expensive per-pixel exp())
float auroraPlume(vec2 p, vec2 center, float invRadiusSq, vec2 warp) {
  vec2 d = (p + warp * 0.25) - center;
  float t = 1.0 + dot(d, d) * invRadiusSq;
  return 1.0 / (t * t);
}

void main() {
  vec2 safeSize = max(uSize, vec2(1.0));
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / safeSize;

  float aspect = safeSize.x / safeSize.y;
  vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
  vec2 focusP = vec2((uFocus.x - 0.5) * aspect, uFocus.y - 0.5);

  float t = uPhase;

  // Single-pass dual-axis Simplex liquid mesh warp (cuts GPU ALU cost by >60%)
  float n1 = snoise(p * 1.18 + vec2(t * 0.24, -t * 0.31));
  float n2 = snoise(p * 1.32 + vec2(4.1 - t * 0.27, 2.7 + t * 0.22) + n1 * 0.65);
  vec2 warp = vec2(n1, n2);

  // Smooth organic drift paths
  vec2 c1Idle = vec2(-0.34 * aspect + 0.22 * sin(t * 0.72), -0.26 + 0.18 * cos(t * 0.58));
  vec2 c2Idle = vec2( 0.32 * aspect + 0.20 * cos(t * 0.64), -0.14 + 0.22 * sin(t * 0.51));
  vec2 c3Idle = vec2(-0.12 * aspect + 0.28 * sin(t * 0.53 + 1.4), 0.30 + 0.16 * cos(t * 0.67));
  vec2 c4Idle = vec2( 0.26 * aspect + 0.18 * cos(t * 0.47 + 2.2), 0.34 + 0.15 * sin(t * 0.61));

  float pull = uActivity * 0.48;
  vec2 c1 = mix(c1Idle, focusP + vec2(-0.18 * aspect, -0.06), pull);
  vec2 c2 = mix(c2Idle, focusP + vec2( 0.16 * aspect, -0.04), pull);
  vec2 c3 = mix(c3Idle, focusP + vec2(-0.06 * aspect,  0.08), pull);
  vec2 c4 = mix(c4Idle, focusP + vec2( 0.12 * aspect,  0.06), pull);

  float invScale = mix(1.0, 1.28, uActivity);
  float w1 = auroraPlume(p, c1, 2.15 * invScale, warp);
  float w2 = auroraPlume(p, c2, 2.35 * invScale, warp * 0.9);
  float w3 = auroraPlume(p, c3, 2.25 * invScale, -warp * 0.85);
  float w4 = auroraPlume(p, c4, 3.10 * invScale, warp.yx * 0.8);

  vec3 electricBlue = vec3(0.259, 0.522, 0.957); // #4285F4
  vec3 cobaltViolet = vec3(0.420, 0.486, 1.000); // #6B7CFF
  vec3 softViolet   = vec3(0.608, 0.447, 0.796); // #9B72CB
  vec3 cyanWhisper  = vec3(0.310, 0.675, 0.996); // #4FACFE
  vec3 roseWhisper  = vec3(0.851, 0.396, 0.439); // #D96570

  float accentMix = 0.5 + 0.5 * sin(t * 0.45 + uv.x * 2.0);
  vec3 accentColor = mix(cyanWhisper, roseWhisper, accentMix * 0.60);

  // Algebraic edge & bottom halo
  float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
  float edgeGlow = (1.0 / (1.0 + edgeDist * 14.0)) * (0.26 + 0.64 * uActivity);
  float bottomDist = max(1.0 - uv.y, 0.0);
  float bottomBloom = (1.0 / (1.0 + bottomDist * 7.5)) * (0.16 + 0.52 * uActivity);
  vec3 edgeSpectrum = mix(
    mix(electricBlue, cobaltViolet, clamp(uv.x * 2.0, 0.0, 1.0)),
    mix(softViolet, accentColor, clamp((uv.x - 0.4) * 1.66, 0.0, 1.0)),
    0.5 + 0.30 * n1
  );

  float meshWave = 0.78 + 0.22 * n2;
  float radVignette = clamp(length(uv - 0.5) * 1.25, 0.0, 1.0);

  // Dark Mode
  vec3 darkBase = mix(
    vec3(0.074, 0.075, 0.080),
    vec3(0.055, 0.055, 0.063),
    radVignette
  );
  float darkGain = mix(1.0, 1.36, uActivity);
  vec3 darkColor = darkBase
    + electricBlue * (w1 * 0.21 * darkGain)
    + cobaltViolet * (w2 * 0.19 * darkGain)
    + softViolet   * (w3 * 0.17 * darkGain)
    + accentColor  * (w4 * 0.11 * darkGain)
    + edgeSpectrum * ((edgeGlow * 0.14 + bottomBloom * 0.12) * meshWave);
  darkColor = darkColor / (vec3(1.0) + max(darkColor - vec3(0.55), vec3(0.0)) * 0.45);

  // Light Mode
  vec3 lightBase = mix(
    vec3(0.976, 0.984, 0.996),
    vec3(0.957, 0.969, 0.990),
    radVignette
  );
  float lightGain = mix(1.0, 1.28, uActivity);
  vec3 lightColor = lightBase;
  lightColor = mix(lightColor, electricBlue, clamp(w1 * 0.13 * lightGain, 0.0, 0.22));
  lightColor = mix(lightColor, cobaltViolet, clamp(w2 * 0.11 * lightGain, 0.0, 0.20));
  lightColor = mix(lightColor, softViolet,   clamp(w3 * 0.10 * lightGain, 0.0, 0.18));
  lightColor = mix(lightColor, accentColor,  clamp(w4 * 0.07 * lightGain, 0.0, 0.14));
  lightColor = mix(lightColor, edgeSpectrum, clamp((edgeGlow * 0.10 + bottomBloom * 0.09) * meshWave, 0.0, 0.18));

  vec3 finalRgb = mix(lightColor, darkColor, uDarkMode);

  // Pure-ALU Interleaved Gradient Noise (~2.2% anti-banding, zero sin() call)
  float ign = fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
  float grain = (ign - 0.5) * mix(0.015, 0.023, uDarkMode);
  finalRgb = clamp(finalRgb + vec3(grain), 0.0, 1.0);

  fragColor = vec4(finalRgb, 1.0);
}
