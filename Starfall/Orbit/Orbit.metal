#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Orbit field. Everything is in points; `ds` is the display scale (pixels per point).
// Ported from the web prototype's fragment shader.

constant float KS = 1.35;      // kernel support in radii: orbs only goo right at contact
constant float KT = 0.091917;  // (1 - 1/KS^2)^3 : boundary sits exactly at r

static float kern(float2 p, float2 c, float r, thread float2 &g) {
    g = float2(0.0);
    if (r < 0.5) return 0.0;
    float2 d = p - c;
    float R = r * KS;
    float q = dot(d, d) / (R * R);
    if (q >= 1.0) return 0.0;
    float a = 1.0 - q;
    g = -6.0 * a * a * d / (R * R);
    return a * a * a;
}

static float hash1(float x) { return fract(sin(x * 12.9898) * 43758.5453); }

static float3 palColor(device const float *pal, int k) {
    return float3(pal[k * 3], pal[k * 3 + 1], pal[k * 3 + 2]);
}

/// orbs:  n × [x, y, r, 0]
/// offs:  n × 5 × [dx, dy, on]   offset of each energy layer behind each orb
/// depth: 5 stacking ranks, 0 = closest to the black body
/// beads: nb × [x, y, intensity, seed, tx, ty, r, g, b]
/// pal:   5 × rgb
[[ stitchable ]] half4 orbField(float2 position, half4 color, float ds, float time, float nf,
                               device const float *orbs, int orbsCount,
                               device const float *offs, int offsCount,
                               device const float *depth, int depthCount,
                               float nbf,
                               device const float *beads, int beadsCount,
                               device const float *pal, int palCount) {
    int n = min(int(nf + 0.5), orbsCount / 4);
    int nb = min(int(nbf + 0.5), beadsCount / 9);
    float2 p = position;
    float aa = 0.9;

    float3 bg = float3(0.843, 0.843, 0.835);
    float2 cell = fmod(p, float2(11.0)) - 5.5;
    float dm = 1.0 - smoothstep(0.5, 1.1, length(cell));
    bg = mix(bg, float3(0.60, 0.60, 0.59), dm * 0.55);

    float F = 0.0; float2 G = float2(0.0); float2 gt; float Fs = 0.0; bool nearAny = false;
    float2 ps = p - float2(0.0, 14.0);
    for (int i = 0; i < n; i++) {
        float2 c = float2(orbs[i * 4], orbs[i * 4 + 1]);
        float r = orbs[i * 4 + 2];
        if (length(p - c) < r * 2.4 + 20.0) nearAny = true;
        F += kern(p, c, r, gt); G += gt;
        Fs += kern(ps, c, r, gt);
    }
    float3 col = bg * (1.0 - smoothstep(KT * 0.15, KT * 1.1, Fs) * 0.13);

    if (nearAny) {
        // one metaball field per energy, so the same colour on two orbs goos together
        float cov[5] = { 0.0, 0.0, 0.0, 0.0, 0.0 };
        for (int c = 0; c < 5; c++) {
            float Fc = 0.0; float2 Gc = float2(0.0);
            for (int i = 0; i < n; i++) {
                int o = (i * 5 + c) * 3;
                if (o + 2 >= offsCount || offs[o + 2] < 0.5) continue;
                float2 oc = float2(orbs[i * 4], orbs[i * 4 + 1]) + float2(offs[o], offs[o + 1]);
                float orr = max(orbs[i * 4 + 2] - 1.4, 0.0);
                Fc += kern(p, oc, orr, gt); Gc += gt;
            }
            if (Fc > 0.0) cov[c] = smoothstep(-0.8, 0.8, (Fc - KT) / max(length(Gc), 1e-5));
        }
        for (int k = 0; k < 5; k++) {           // paint back to front
            float d = float(4 - k);
            for (int c = 0; c < 5 && c < depthCount; c++) {
                if (abs(depth[c] - d) < 0.5) col = mix(col, palColor(pal, c), cov[c]);
            }
        }
        float ed = (F - KT) / max(length(G), 1e-5);
        float alpha = smoothstep(-aa, aa, ed);
        if (alpha > 0.0) {
            float e0 = max(ed, 0.0);
            float3 bc = float3(0.016, 0.018, 0.026) + float3(0.58, 0.60, 0.66) * exp(-e0 / 1.3) * 0.14;
            col = mix(col, bc, alpha);
        }
    }

    // shimmer beads
    for (int k = 0; k < nb; k++) {
        int b = k * 9;
        float2 bp = float2(beads[b], beads[b + 1]);
        float seed = beads[b + 3];
        float I = beads[b + 2] * (0.84 + 0.12 * sin(time * 4.7 + seed * 3.1) + 0.08 * sin(time * 11.3 + seed * 7.7));
        float2 t = float2(beads[b + 4], beads[b + 5]);
        float2 nrm = float2(-t.y, t.x);
        float2 dp = p - bp;
        float u = dot(dp, t), v = dot(dp, nrm), d = length(dp);
        float cs = 1.8 * (0.7 + I);
        float core = exp(-d * d / (cs * cs));
        float streak = exp(-abs(v) / 0.9) * exp(-abs(u) / (14.0 * (0.35 + I)));
        float halo = exp(-d / (10.0 * (0.45 + I))) * 0.32;
        float hv = hash1(floor(u / 3.5 + 0.5) * 1.37 + seed * 17.0 + floor(time * 6.0 + seed));
        float fleck = step(0.86, hv) * exp(-abs(u) / 44.0) * exp(-abs(v - (hv - 0.93) * 30.0) / 0.9);
        float3 warm = mix(float3(1.0, 0.88, 0.68), float3(beads[b + 6], beads[b + 7], beads[b + 8]), 0.3);
        col += (float3(1.0, 0.98, 0.94) * core * 1.3 + warm * (streak * 0.85 + halo)) * I
             + float3(0.98, 0.32, 0.62) * fleck * I * 0.75;
    }
    return half4(half3(min(col, float3(1.0))), 1.0h);
}

// MARK: - Tab bar orb: a single orb that slides between tabs and settles into the icon's shape.

static float sdCircle(float2 p, float r) { return length(p) - r; }
static float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, float2(0.0))) + min(max(d.x, d.y), 0.0);
}
static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
static float2 rot45(float2 p) {
    const float s = 0.70710678;
    return float2(s * (p.x + p.y), s * (p.y - p.x));
}
static float iconSD(float2 p, int icon) {
    if (icon == 0) {        // friends: two souls overlapping
        return smin(sdCircle(p - float2(-4.5, -1.5), 7.0), sdCircle(p - float2(5.5, 2.0), 5.5), 1.5);
    } else if (icon == 1) { // home
        float body = sdBox(p - float2(0.0, 4.5), float2(7.0, 5.5)) - 1.2;
        float roof = sdBox(rot45(p - float2(0.0, -2.0)), float2(6.8, 6.8)) - 1.2;
        return min(body, roof);
    } else if (icon == 2) { // inbox: a speech bubble
        float b = sdCircle(p - float2(0.0, -1.0), 9.5);
        float tail = sdBox(rot45(p - float2(-6.0, 7.0)), float2(3.0, 3.0)) - 0.8;
        return smin(b, tail, 1.5);
    }
    // profile: head and shoulders
    float head = sdCircle(p - float2(0.0, -5.0), 5.2);
    float sh = max(sdCircle(p - float2(0.0, 12.5), 10.5), p.y - 10.0);
    return min(head, sh);
}
static float tabShape(float2 p, float morph, int icon, float stretch) {
    float2 q = float2(p.x / stretch, p.y * stretch);
    return mix(sdCircle(q, 12.5), iconSD(q, icon), morph);
}

/// orb: centre in the bar's local points. offs: 5 × [dx, dy] trail offsets per energy.
[[ stitchable ]] half4 tabOrb(float2 position, half4 color, float2 orb, float morph, float iconf, float stretch,
                             device const float *offs, int offsCount,
                             device const float *depth, int depthCount,
                             device const float *pal, int palCount) {
    float2 p = position - orb;
    int icon = int(iconf + 0.5);
    float3 acc = float3(0.0);
    float alpha = 0.0;
    for (int k = 0; k < 5; k++) {
        float d = float(4 - k);
        for (int c = 0; c < 5 && c < depthCount; c++) {
            if (abs(depth[c] - d) > 0.5 || c * 2 + 1 >= offsCount) continue;
            float2 o = float2(offs[c * 2], offs[c * 2 + 1]);
            if (length(o) < 0.3) continue;
            float sd = tabShape(p - o, morph, icon, stretch) + 0.5;
            float cov = 1.0 - smoothstep(-0.6, 0.6, sd);
            acc = palColor(pal, c) * cov + acc * (1.0 - cov);
            alpha = cov + alpha * (1.0 - cov);
        }
    }
    float sd = tabShape(p, morph, icon, stretch);
    float cov = 1.0 - smoothstep(-0.6, 0.6, sd);
    float3 ink = float3(0.039, 0.039, 0.047) + float3(0.5) * exp(-max(-sd, 0.0) / 1.1) * 0.12 * cov;
    acc = ink * cov + acc * (1.0 - cov);
    alpha = cov + alpha * (1.0 - cov);
    return half4(half3(acc), half(alpha));
}
