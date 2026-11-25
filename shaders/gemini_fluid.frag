#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniform layout (strict float order for Flutter FragmentShader.setFloat):
// [0, 1] uSize       : viewport width, height in logical/physical pixels
// [2]    uPhase      : integrated continuous fluid phase
// [3]    uActivity   : 0.0 = Idle calm aurora, 1.0 = Active / Focus / Syncing
// [4]    uDarkMode   : 1.0 = Dark (#0E0E10~#131314), 0.0 = Light (#F8FAFD)
// [5, 6] uFocus      : normalized [0..1] focal point for active convergence
uniform vec2 uSize;
uniform float uPhase;
uniform float uActivity;
uniform float uDarkMode;
uniform vec2 uFocus;

out vec4 fragColor;

// -----------------------------------------------------------------------------
// 2D Simplex Noise (Ashima Arts / Stefan Gustavson - MIT License)
// -----------------------------------------------------------------------------
vec3 mod289_3(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289_2(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289_3(((x * 34.0) + 10.0) * x);
}

float snoise(vec2 v) {
  const vec4 C = vec4(
    0.211324865405187,  // (3.0 - sqrt(3.0)) / 6.0
    0.366025403784439,  // 0.5 * (sqrt(3.0) - 1.0)
   -0.577350269189626,  // -1.0 + 2.0 * C.x
    0.024390243902439   // 1.0 / 41.0
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

// Soft organic Gaussian plume deformed by liquid mesh warp
float auroraPlume(vec2 p, vec2 center, float radius, vec2 warp) {
  vec2 d = (p + warp * 0.24) - center;
  float distSq = dot(d, d) / max(radius * radius, 0.001);
  return exp(-distSq * 1.45);
}

void main() {
  vec2 safeSize = max(uSize, vec2(1.0));
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / safeSize;

  // Aspect-corrected coordinates centered around [0.5, 0.5]
  float aspect = safeSize.x / safeSize.y;
  vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
  vec2 focusP = vec2((uFocus.x - 0.5) * aspect, uFocus.y - 0.5);

  float t = uPhase;

  // 2-Pass Domain Warping for silky liquid mesh deformation
  vec2 q = vec2(
    snoise(p * 1.05 + vec2(0.0, t * 0.34)),
    snoise(p * 1.05 + vec2(4.7, -t * 0.29))
  );
  vec2 warp = vec2(
    snoise(p * 1.35 + 1.15 * q + vec2(1.9 + t * 0.42, 7.3)),
    snoise(p * 1.35 + 1.15 * q + vec2(6.4, 2.6 - t * 0.37))
  );

  // Organic Lissajous / Bezier-like idle trajectories (18s - 26s full cycle)
  vec2 c1Idle = vec2(-0.34 * aspect + 0.22 * sin(t * 0.72), -0.26 + 0.18 * cos(t * 0.58));
  vec2 c2Idle = vec2( 0.32 * aspect + 0.20 * cos(t * 0.64), -0.14 + 0.22 * sin(t * 0.51));
  vec2 c3Idle = vec2(-0.12 * aspect + 0.28 * sin(t * 0.53 + 1.4), 0.30 + 0.16 * cos(t * 0.67));
  vec2 c4Idle = vec2( 0.26 * aspect + 0.18 * cos(t * 0.47 + 2.2), 0.34 + 0.15 * sin(t * 0.61));

  // Smooth convergence toward uFocus when Active / Generating / Focused
  float pull = uActivity * 0.48;
  vec2 c1 = mix(c1Idle, focusP + vec2(-0.18 * aspect, -0.06), pull);
  vec2 c2 = mix(c2Idle, focusP + vec2( 0.16 * aspect, -0.04), pull);
  vec2 c3 = mix(c3Idle, focusP + vec2(-0.06 * aspect,  0.08), pull);
  vec2 c4 = mix(c4Idle, focusP + vec2( 0.12 * aspect,  0.06), pull);

  // Subtle slow breathing envelope
  float breath1 = 0.90 + 0.10 * sin(t * 0.85);
  float breath2 = 0.90 + 0.10 * cos(t * 0.74 + 1.1);
  float breath3 = 0.90 + 0.10 * sin(t * 0.68 + 2.5);

  float rScale = mix(1.0, 0.86, uActivity);
  float w1 = auroraPlume(p, c1, 0.68 * rScale, warp) * breath1;
  float w2 = auroraPlume(p, c2, 0.64 * rScale, warp * 0.9) * breath2;
  float w3 = auroraPlume(p, c3, 0.66 * rScale, -warp * 0.85) * breath3;
  float w4 = auroraPlume(p, c4, 0.54 * rScale, warp.yx * 0.8);

  // Gemini Core Spectrum
  vec3 electricBlue = vec3(0.259, 0.522, 0.957); // #4285F4
  vec3 cobaltViolet = vec3(0.420, 0.486, 1.000); // #6B7CFF
  vec3 softViolet   = vec3(0.608, 0.447, 0.796); // #9B72CB
  vec3 cyanWhisper  = vec3(0.310, 0.675, 0.996); // #4FACFE
  vec3 roseWhisper  = vec3(0.851, 0.396, 0.439); // #D96570

  // Restrained cyan/rose accent modulation
  float accentMix = 0.5 + 0.5 * sin(t * 0.45 + uv.x * 2.2);
  vec3 accentColor = mix(cyanWhisper, roseWhisper, accentMix * 0.62);

  // Subtle Gemini viewport-edge & bottom breathing halo
  float edgeX = min(uv.x, 1.0 - uv.x);
  float edgeY = min(uv.y, 1.0 - uv.y);
  float edgeDist = min(edgeX, edgeY);
  float edgeGlow = exp(-edgeDist * 7.5) * (0.32 + 0.68 * uActivity);
  float bottomBloom = exp(-max(1.0 - uv.y, 0.0) * 4.2) * (0.18 + 0.55 * uActivity);
  vec3 edgeSpectrum = mix(
    mix(electricBlue, cobaltViolet, smoothstep(0.0, 0.5, uv.x)),
    mix(softViolet, accentColor, smoothstep(0.4, 1.0, uv.x)),
    0.5 + 0.35 * warp.x
  );

  // Liquid ribbon modulation from domain-warped simplex field
  float meshWave = 0.5 + 0.5 * snoise(p * 1.6 + warp * 0.95);

  // ---------------------------------------------------------------------------
  // Dark Mode Composition (#0E0E10 ~ #131314 base, 12% - 26% diffused aurora)
  // ---------------------------------------------------------------------------
  float radVignette = clamp(length(uv - 0.5) * 1.25, 0.0, 1.0);
  vec3 darkBase = mix(
    vec3(0.074, 0.075, 0.080), // #131314 center
    vec3(0.055, 0.055, 0.063), // #0E0E10 deep charcoal periphery
    radVignette
  );

  float darkGain = mix(1.0, 1.38, uActivity);
  vec3 darkColor = darkBase;
  darkColor += electricBlue * (w1 * 0.21 * darkGain);
  darkColor += cobaltViolet * (w2 * 0.19 * darkGain);
  darkColor += softViolet   * (w3 * 0.17 * darkGain);
  darkColor += accentColor  * (w4 * 0.11 * darkGain);
  darkColor += edgeSpectrum * ((edgeGlow * 0.16 + bottomBloom * 0.14) * (0.75 + 0.25 * meshWave));

  // Soft highlight compression so dark mode never clips into harsh neon
  darkColor = darkColor / (vec3(1.0) + max(darkColor - vec3(0.55), vec3(0.0)) * 0.45);

  // ---------------------------------------------------------------------------
  // Light Mode Composition (#F8FAFD base, 8% - 16% airy mist glow)
  // ---------------------------------------------------------------------------
  vec3 lightBase = mix(
    vec3(0.976, 0.984, 0.996), // #F9FBFE center
    vec3(0.957, 0.969, 0.990), // #F4F7FC soft cool edge
    radVignette
  );

  float lightGain = mix(1.0, 1.30, uActivity);
  vec3 lightColor = lightBase;
  lightColor = mix(lightColor, electricBlue, clamp(w1 * 0.13 * lightGain, 0.0, 0.22));
  lightColor = mix(lightColor, cobaltViolet, clamp(w2 * 0.11 * lightGain, 0.0, 0.20));
  lightColor = mix(lightColor, softViolet,   clamp(w3 * 0.10 * lightGain, 0.0, 0.18));
  lightColor = mix(lightColor, accentColor,  clamp(w4 * 0.07 * lightGain, 0.0, 0.14));
  lightColor = mix(lightColor, edgeSpectrum, clamp((edgeGlow * 0.11 + bottomBloom * 0.10) * meshWave, 0.0, 0.18));

  vec3 finalRgb = mix(lightColor, darkColor, uDarkMode);

  // ---------------------------------------------------------------------------
  // Anti-Banding Procedural Film Grain / Interleaved Gradient Noise (~2.3%)
  // ---------------------------------------------------------------------------
  float ign = fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
  float microHash = fract(sin(dot(fragCoord + fract(t) * 13.7, vec2(12.9898, 78.233))) * 43758.5453);
  float grain = (mix(ign, microHash, 0.35) - 0.5) * mix(0.016, 0.025, uDarkMode);
  finalRgb = clamp(finalRgb + vec3(grain), 0.0, 1.0);

  fragColor = vec4(finalRgb, 1.0);
}
