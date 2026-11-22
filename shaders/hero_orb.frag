#version 460 core

#include <flutter/runtime_effect.glsl>

// The start ring's orb (design artifact "RoutaMi AMOLED"): a slowly turning
// Julia set lit in the accent colour, fading out towards the rim.
uniform vec2 uSize;
uniform float uTime;
uniform vec4 uColor;

out vec4 fragColor;

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uSize) / uSize.y * 2.0;
  float r = length(uv);
  float a = uTime * 0.25;
  uv = mat2(cos(a), sin(a), -sin(a), cos(a)) * uv;
  vec2 z = uv * 1.15;
  vec2 c = vec2(-0.8 + 0.04 * cos(uTime * 0.31), 0.156 + 0.04 * sin(uTime * 0.27));
  float n = 0.0;
  float m = 0.0;
  for (int i = 0; i < 90; i++) {
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    m = dot(z, z);
    if (m > 64.0) {
      break;
    }
    n += 1.0;
  }
  float k = m <= 64.0 ? 0.0 : (n - log2(log2(m)) + 4.0) / 90.0;
  float glow = pow(clamp(k * 2.2, 0.0, 1.0), 0.8);
  float alpha = glow * 0.85 * smoothstep(1.02, 0.7, r) * uColor.a;
  fragColor = vec4(uColor.rgb * alpha, alpha);
}
