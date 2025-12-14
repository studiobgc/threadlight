#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// MARK: - Utility Functions

float roundedBoxSDF(float2 center, float2 size, float radius) {
    float2 q = abs(center) - size + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float smoothEdge(float distance, float smoothness) {
    return 1.0 - smoothstep(-smoothness, smoothness, distance);
}

// MARK: - Grid Shader

struct GridVertexOut {
    float4 position [[position]];
    float2 worldPos;
};

vertex GridVertexOut gridVertexShader(
    uint vertexID [[vertex_id]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    // Full-screen quad
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    
    float2 pos = positions[vertexID];
    
    GridVertexOut out;
    out.position = float4(pos, 0, 1);
    
    // Calculate world position for this pixel
    float2 screenPos = (pos * 0.5 + 0.5) * uniforms.viewportSize;
    out.worldPos = (screenPos - uniforms.pan) / uniforms.zoom;
    
    return out;
}

fragment float4 gridFragmentShader(
    GridVertexOut in [[stage_in]],
    constant GridUniforms &grid [[buffer(BufferIndexGridUniforms)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float2 worldPos = in.worldPos;
    float zoom = uniforms.zoom;
    
    // DESIGN SYSTEM: bg0 = #09090b (deepest black)
    float4 color = float4(0.035, 0.035, 0.043, 1.0);
    
    // Fade grid at low zoom
    if (zoom < 0.15) {
        return color;
    }
    
    float gridOpacity = saturate((zoom - 0.15) / 0.35);
    
    // UTILITARIAN: Simple dot grid (no fancy lines)
    float majorSize = 100.0;
    float2 gridCell = fmod(abs(worldPos), majorSize);
    float dotDist = length(gridCell - majorSize * 0.5);
    
    // Small, crisp dots
    float dotSize = max(1.5, 2.0 / zoom);
    float dot = smoothstep(dotSize + 0.3, dotSize - 0.3, dotDist);
    
    // Subtle dot color
    float4 dotColor = float4(0.18, 0.18, 0.20, 1.0);
    color = mix(color, dotColor, dot * gridOpacity * 0.8);
    
    // Origin crosshair - simple, no glow
    float originWidth = 1.5 / zoom;
    float originX = smoothstep(originWidth, 0, abs(worldPos.x));
    float originY = smoothstep(originWidth, 0, abs(worldPos.y));
    float origin = max(originX, originY);
    
    // DS accent: #f97316 (orange)
    float4 originColor = float4(0.976, 0.451, 0.086, 1.0);
    color = mix(color, originColor, origin * 0.5 * saturate(zoom));
    
    return color;
}
// MARK: - Node Shader (Instanced)

struct NodeVertexOut {
    float4 position [[position]];
    float2 localPos;
    float2 size;
    float4 backgroundColor;
    float4 headerColor;
    float4 borderColor;
    float cornerRadius;
    float borderWidth;
    float glowIntensity;
    float isSelected;
    float isHovered;
};

vertex NodeVertexOut nodeVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant NodeVertex *vertices [[buffer(BufferIndexVertices)]],
    constant NodeInstanceData *instances [[buffer(BufferIndexInstances)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    NodeVertex vert = vertices[vertexID];
    NodeInstanceData instance = instances[instanceID];
    
    // Scale unit quad by node size to get local coordinates
    float2 scaledPos = vert.position * instance.size;
    float4 worldPos = instance.transform * float4(scaledPos, 0, 1);
    float4 clipPos = uniforms.viewProjectionMatrix * worldPos;
    
    NodeVertexOut out;
    out.position = clipPos;
    out.localPos = scaledPos;  // Pass scaled coords for SDF
    out.size = instance.size;
    out.backgroundColor = instance.backgroundColor;
    out.headerColor = instance.headerColor;
    out.borderColor = instance.borderColor;
    out.cornerRadius = instance.cornerRadius;
    out.borderWidth = instance.borderWidth;
    out.glowIntensity = instance.glowIntensity;
    out.isSelected = instance.isSelected;
    out.isHovered = instance.isHovered;
    
    return out;
}

fragment float4 nodeFragmentShader(
    NodeVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float2 pos = in.localPos;
    float2 halfSize = in.size * 0.5;
    float2 center = pos - halfSize;
    
    // SUSAN KARE 2030: Crisp, pixel-perfect edges
    float cornerRadius = 4.0; // Smaller, tighter corners
    float dist = roundedBoxSDF(center, halfSize, cornerRadius);
    
    // Ultra-crisp edge (no blur)
    float aa = fwidth(dist) * 0.8;
    float shape = smoothEdge(dist, aa);
    
    if (shape < 0.001) {
        discard_fragment();
    }
    
    // UTILITARIAN: Flat header, no gradients
    float headerHeight = 24.0; // Compact header
    float headerMask = step(halfSize.y - headerHeight, -center.y);
    
    // DESIGN SYSTEM: bg2 = #18181b
    float4 bodyColor = float4(0.094, 0.094, 0.106, 1.0);
    float4 headerColor = in.headerColor;
    float4 baseColor = mix(bodyColor, headerColor, headerMask);
    
    // MINIMAL CHROME: 1px border, high contrast
    float borderWidth = 1.0;
    float borderDist = abs(dist) - borderWidth * 0.5;
    float borderMask = smoothEdge(borderDist, aa * 0.5);
    
    // DS border0: #27272a
    float4 borderColor = float4(0.153, 0.153, 0.165, 1.0);
    
    // Selection: DS accent #f97316
    if (in.isSelected > 0.5) {
        borderColor = float4(0.976, 0.451, 0.086, 1.0);
        borderWidth = 2.0;
    }
    
    // Hover: DS border2 #52525b
    if (in.isHovered > 0.5 && in.isSelected < 0.5) {
        borderColor = float4(0.322, 0.322, 0.357, 1.0);
    }
    
    // MICRO-ANIMATION: Subtle selection pulse (GPU-friendly)
    if (in.isSelected > 0.5) {
        float pulse = 0.9 + 0.1 * sin(uniforms.time * 4.0);
        borderColor.rgb *= pulse;
    }
    
    // Clean combine - no blending tricks
    float4 color = baseColor;
    color = mix(color, borderColor, (1.0 - borderMask) * shape);
    color.a = shape;
    
    // Header divider line (1px, crisp)
    float dividerY = halfSize.y - headerHeight;
    float divider = smoothstep(0.5, -0.5, abs(center.y + dividerY) - 0.5);
    color.rgb = mix(color.rgb, float3(0.2, 0.2, 0.22), divider * headerMask);
    
    return color;
}
// MARK: - Connection Shader

struct ConnectionVertexOut {
    float4 position [[position]];
    float4 color;
    float progress;
    float distanceAlongCurve;
};

vertex ConnectionVertexOut connectionVertexShader(
    uint vertexID [[vertex_id]],
    constant ConnectionVertex *vertices [[buffer(BufferIndexVertices)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    ConnectionVertex vert = vertices[vertexID];
    
    float2 screenPos = vert.position * uniforms.zoom + uniforms.pan;
    float2 clipPos = (screenPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y;
    
    ConnectionVertexOut out;
    out.position = float4(clipPos, 0, 1);
    out.color = vert.color;
    out.progress = vert.progress;
    out.distanceAlongCurve = vert.progress;
    
    return out;
}

fragment float4 connectionFragmentShader(
    ConnectionVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float4 color = in.color;
    
    // Animated flow effect
    float flow = fract(in.distanceAlongCurve * 10.0 - uniforms.time * 2.0);
    float flowPulse = smoothstep(0.0, 0.3, flow) * smoothstep(1.0, 0.7, flow);
    
    // Subtle pulsing glow
    color.rgb += flowPulse * 0.2;
    
    return color;
}

// MARK: - Connection Preview (Dashed)

fragment float4 connectionPreviewFragmentShader(
    ConnectionVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float4 color = in.color;
    
    // Animated dashes
    float dashPattern = fract((in.distanceAlongCurve * 20.0) - uniforms.time * 5.0);
    float dash = step(0.5, dashPattern);
    
    color.a *= dash;
    
    // Glow effect
    float glow = 0.5 + 0.5 * sin(uniforms.time * 3.0);
    color.rgb += glow * 0.2;
    
    return color;
}

// MARK: - Port Shader

struct PortVertexOut {
    float4 position [[position]];
    float2 center;
    float radius;
    float4 color;
    float isConnected;
    float isHovered;
    float glowIntensity;
};

vertex PortVertexOut portVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2 *quadVerts [[buffer(0)]],
    constant PortData *ports [[buffer(BufferIndexInstances)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    PortData port = ports[instanceID];
    float2 quadPos = quadVerts[vertexID];
    
    float size = port.radius * 2.5; // Extra space for glow
    float2 worldPos = port.position + quadPos * size;
    float2 screenPos = worldPos * uniforms.zoom + uniforms.pan;
    float2 clipPos = (screenPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y;
    
    PortVertexOut out;
    out.position = float4(clipPos, 0, 1);
    out.center = quadPos * size;
    out.radius = port.radius;
    out.color = port.color;
    out.isConnected = port.isConnected;
    out.isHovered = port.isHovered;
    out.glowIntensity = port.glowIntensity;
    
    return out;
}

fragment float4 portFragmentShader(
    PortVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float dist = length(in.center);
    float aa = fwidth(dist);
    
    // Main port circle
    float circle = smoothstep(in.radius + aa, in.radius - aa, dist);
    
    if (circle < 0.001) {
        discard_fragment();
    }
    
    float4 color = in.color;
    
    // Connected glow
    if (in.isConnected > 0.5) {
        float glow = exp(-(dist - in.radius) * 0.3) * 0.5;
        color.rgb += float3(0.494, 0.827, 0.129) * glow; // Green glow
    }
    
    // Hover effect
    if (in.isHovered > 0.5) {
        // Inner highlight
        float innerDist = dist - (in.radius - 3);
        float inner = smoothstep(0, 2, innerDist);
        color.rgb = mix(color.rgb + 0.3, color.rgb, inner);
    }
    
    // Border
    float borderWidth = in.isHovered > 0.5 ? 2.0 : 1.5;
    float borderDist = abs(dist - in.radius) - borderWidth * 0.5;
    float border = smoothstep(aa, -aa, borderDist);
    float3 borderColor = in.isHovered > 0.5 ? float3(1.0) : float3(1.0, 1.0, 1.0) * 0.7;
    
    color.rgb = mix(color.rgb, borderColor, border);
    color.a = circle;
    
    return color;
}

// MARK: - Selection Box Shader

struct SelectionBoxVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex SelectionBoxVertexOut selectionBoxVertexShader(
    uint vertexID [[vertex_id]],
    constant float4 *rect [[buffer(0)]], // x, y, width, height
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    float4 r = rect[0];
    
    float2 positions[6] = {
        float2(r.x, r.y),
        float2(r.x + r.z, r.y),
        float2(r.x, r.y + r.w),
        float2(r.x, r.y + r.w),
        float2(r.x + r.z, r.y),
        float2(r.x + r.z, r.y + r.w)
    };
    
    float2 uvs[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(0, 1), float2(1, 0), float2(1, 1)
    };
    
    float2 worldPos = positions[vertexID];
    float2 screenPos = worldPos * uniforms.zoom + uniforms.pan;
    float2 clipPos = (screenPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y;
    
    SelectionBoxVertexOut out;
    out.position = float4(clipPos, 0, 1);
    out.uv = uvs[vertexID];
    
    return out;
}

fragment float4 selectionBoxFragmentShader(
    SelectionBoxVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    // Fill
    float4 fillColor = float4(0.486, 0.227, 0.929, 0.1);
    
    // Dashed border
    float2 uv = in.uv;
    float borderWidth = 0.02;
    
    bool nearEdge = uv.x < borderWidth || uv.x > 1.0 - borderWidth ||
                    uv.y < borderWidth || uv.y > 1.0 - borderWidth;
    
    if (nearEdge) {
        // Animated dash
        float dashFreq = 20.0;
        float dash = step(0.5, fract((uv.x + uv.y) * dashFreq - uniforms.time * 2.0));
        return mix(fillColor, float4(0.486, 0.227, 0.929, dash), 0.8);
    }
    
    return fillColor;
}
