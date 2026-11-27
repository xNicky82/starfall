#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float h21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

constant float bayer4[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

/// Ordered palette dither: each cell becomes one of five tones of the light's own hue
/// (black → deep → hue → pale → white), like a printed night sky.
[[ stitchable ]] half4 stipple(float2 pos, SwiftUI::Layer layer, float cell, float gain, float specks, float seed) {
    float2 q = floor(pos / cell);
    half4 c = layer.sample((q + 0.5) * cell);
    float m = max(max(float(c.r), float(c.g)), float(c.b));
    float lum = clamp(m * gain, 0.0, 1.0);

    int ix = int(q.x) & 3, iy = int(q.y) & 3;
    float b = (bayer4[ix + iy * 4] + 0.5) / 16.0;
    float thr = mix(b, h21(q + seed * 17.0), 0.5);

    float v = lum * 4.0;
    float lvl = min(4.0, floor(v) + step(thr, fract(v)));

    if (lvl >= 1.0 && m > 0.003) {
        float3 hue = float3(c.rgb) / m;
        float3 col;
        if (lvl < 1.5)      col = hue * 0.30;
        else if (lvl < 2.5) col = hue * 0.72;
        else if (lvl < 3.5) col = mix(hue, float3(1.0), 0.45);
        else                col = mix(hue, float3(1.0), 0.88);
        return half4(half3(col), 1.0h);
    }
    if (specks > 0.0 && h21(q * 1.37 + 91.0 + seed) < specks) {
        float g = 0.16 + 0.45 * h21(q + 7.0);
        return half4(half3(g), 1.0h);
    }
    return half4(0.0h, 0.0h, 0.0h, c.a);
}
