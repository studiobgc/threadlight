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
    
    // Background color
    float4 color = grid.backgroundColor;
    
    // Fade grid at low zoom
    if (zoom < 0.15) {
        return color;
    }
    
    float gridOpacity = saturate((zoom - 0.15) / 0.35);
    
    // Minor grid dots
    if (zoom > 0.4) {
        float minorSize = grid.minorGridSize;
        float2 minorGrid = fmod(abs(worldPos), minorSize);
        float minorDist = length(minorGrid - minorSize * 0.5);
        
        // Skip major grid intersections
        float2 majorGrid = fmod(abs(worldPos), grid.majorGridSize);
        bool isMajorIntersection = length(majorGrid - grid.majorGridSize * 0.5) < minorSize;
        
        if (!isMajorIntersection) {
            float dotSize = max(1.0, 1.5 / zoom);
            float dot = smoothstep(dotSize + 0.5, dotSize - 0.5, minorDist);
            color = mix(color, float4(0.29, 0.29, 0.42, 1.0), dot * 0.4 * gridOpacity);
        }
    }
    
    // Major grid lines
    float majorSize = grid.majorGridSize;
    float2 majorGrid = fmod(abs(worldPos), majorSize);
    float lineWidth = 1.0 / zoom;
    
    float lineX = smoothstep(lineWidth, 0, abs(majorGrid.x));
    float lineY = smoothstep(lineWidth, 0, abs(majorGrid.y));
    float majorLine = max(lineX, lineY);
    
    color = mix(color, grid.majorGridColor, majorLine * 0.6 * gridOpacity);
    
    // Origin crosshair with glow
    float originDist = min(abs(worldPos.x), abs(worldPos.y));
    float originLine = smoothstep(2.0 / zoom, 0, originDist);
    float4 originColor = float4(0.486, 0.227, 0.929, 1.0); // Purple
    
    // Add glow
    float glowDist = min(abs(worldPos.x), abs(worldPos.y));
    float glow = exp(-glowDist * zoom * 0.1) * 0.3;
    
    color = mix(color, originColor, (originLine * 0.6 + glow) * saturate(zoom));
    
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
    
    // SDF for rounded rectangle
    float dist = roundedBoxSDF(center, halfSize, in.cornerRadius);
    
    // Crisp anti-aliased edge
    float aa = fwidth(dist) * 1.0;
    float shape = smoothEdge(dist, aa);
    
    if (shape < 0.001) {
        discard_fragment();
    }
    
    // Header region (top 30px)
    float headerHeight = 30.0;
    float headerMask = smoothstep(halfSize.y - headerHeight - 1, halfSize.y - headerHeight + 1, -center.y);
    
    // Simple colors - no gradients, no fancy effects
    float4 baseColor = mix(in.backgroundColor, in.headerColor, headerMask);
    
    // Border - simple and clean
    float borderDist = abs(dist) - in.borderWidth * 0.5;
    float borderMask = smoothEdge(borderDist, aa);
    float4 borderColor = in.borderColor;
    
    // Selection: just brighter border
    if (in.isSelected > 0.5) {
        borderColor = float4(0.486, 0.227, 0.929, 1.0);
    }
    
    // Hover: subtle border change
    if (in.isHovered > 0.5 && in.isSelected < 0.5) {
        borderColor = float4(0.5, 0.4, 0.8, 1.0);
    }
    
    // Combine - simple blend
    float4 color = mix(baseColor, borderColor, (1.0 - borderMask) * shape);
    color.a *= shape;
    
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
