#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// MARK: - Bloom Effect

struct BloomVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex BloomVertexOut bloomVertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    
    float2 texCoords[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };
    
    BloomVertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

// Extract bright pixels
fragment float4 bloomThresholdShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    constant BloomParams &params [[buffer(BufferIndexBloomParams)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    
    // Calculate luminance
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    
    // Extract bright areas
    float brightness = max(0.0, luminance - params.threshold);
    
    return float4(color.rgb * brightness, 1.0);
}

// Gaussian blur (horizontal)
fragment float4 bloomBlurHShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    constant BloomParams &params [[buffer(BufferIndexBloomParams)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(colorTexture.get_width(), colorTexture.get_height());
    
    // 9-tap Gaussian blur
    float weights[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    
    float4 result = colorTexture.sample(textureSampler, in.texCoord) * weights[0];
    
    for (int i = 1; i < 5; i++) {
        float2 offset = float2(texelSize.x * float(i) * params.radius, 0);
        result += colorTexture.sample(textureSampler, in.texCoord + offset) * weights[i];
        result += colorTexture.sample(textureSampler, in.texCoord - offset) * weights[i];
    }
    
    return result;
}

// Gaussian blur (vertical)
fragment float4 bloomBlurVShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    constant BloomParams &params [[buffer(BufferIndexBloomParams)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    
    float2 texelSize = 1.0 / float2(colorTexture.get_width(), colorTexture.get_height());
    
    float weights[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    
    float4 result = colorTexture.sample(textureSampler, in.texCoord) * weights[0];
    
    for (int i = 1; i < 5; i++) {
        float2 offset = float2(0, texelSize.y * float(i) * params.radius);
        result += colorTexture.sample(textureSampler, in.texCoord + offset) * weights[i];
        result += colorTexture.sample(textureSampler, in.texCoord - offset) * weights[i];
    }
    
    return result;
}

// Combine original + bloom
fragment float4 bloomCompositeShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    texture2d<float> bloomTexture [[texture(TextureIndexBloom)]],
    constant BloomParams &params [[buffer(BufferIndexBloomParams)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    float4 bloom = bloomTexture.sample(textureSampler, in.texCoord);
    
    return color + bloom * params.intensity;
}

// MARK: - Particle System

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
    float life;
};

vertex ParticleVertexOut particleVertexShader(
    uint vertexID [[vertex_id]],
    constant Particle *particles [[buffer(BufferIndexParticles)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    Particle p = particles[vertexID];
    
    float2 screenPos = p.position * uniforms.zoom + uniforms.pan;
    float2 clipPos = (screenPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y;
    
    ParticleVertexOut out;
    out.position = float4(clipPos, 0, 1);
    out.color = p.color;
    out.size = p.size * uniforms.zoom;
    out.life = p.life / p.maxLife;
    
    return out;
}

fragment float4 particleFragmentShader(
    ParticleVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Circular particle with soft edge
    float dist = length(pointCoord - 0.5) * 2.0;
    float alpha = smoothstep(1.0, 0.0, dist);
    
    // Fade based on life
    alpha *= in.life;
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Particle Compute Shader (Physics Update)

kernel void updateParticles(
    device Particle *particles [[buffer(BufferIndexParticles)]],
    constant float &deltaTime [[buffer(1)]],
    constant float2 &gravity [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    Particle p = particles[id];
    
    // Update life
    p.life -= deltaTime;
    
    if (p.life > 0) {
        // Apply gravity
        p.velocity += gravity * deltaTime;
        
        // Apply velocity
        p.position += p.velocity * deltaTime;
        
        // Fade color
        float lifeFactor = p.life / p.maxLife;
        p.color.a = lifeFactor;
        
        // Shrink
        p.size *= 0.99;
    }
    
    particles[id] = p;
}

// MARK: - Ambient Occlusion for Nodes

fragment float4 nodeAOShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> depthTexture [[texture(0)]],
    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 texelSize = 1.0 / float2(depthTexture.get_width(), depthTexture.get_height());
    
    float centerDepth = depthTexture.sample(textureSampler, in.texCoord).r;
    
    // Sample surrounding pixels
    float ao = 0.0;
    int samples = 8;
    float radius = 3.0;
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 6.28318 / float(samples);
        float2 offset = float2(cos(angle), sin(angle)) * texelSize * radius;
        float sampleDepth = depthTexture.sample(textureSampler, in.texCoord + offset).r;
        ao += step(centerDepth, sampleDepth);
    }
    
    ao /= float(samples);
    ao = 1.0 - ao * 0.5;
    
    return float4(ao, ao, ao, 1.0);
}

// MARK: - Chromatic Aberration (Subtle effect for selected nodes)

fragment float4 chromaticAberrationShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    constant float &intensity [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 center = float2(0.5);
    float2 dir = in.texCoord - center;
    float dist = length(dir);
    
    float2 offset = dir * dist * intensity * 0.02;
    
    float r = colorTexture.sample(textureSampler, in.texCoord + offset).r;
    float g = colorTexture.sample(textureSampler, in.texCoord).g;
    float b = colorTexture.sample(textureSampler, in.texCoord - offset).b;
    float a = colorTexture.sample(textureSampler, in.texCoord).a;
    
    return float4(r, g, b, a);
}

// MARK: - Vignette Effect

fragment float4 vignetteShader(
    BloomVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(TextureIndexColor)]],
    constant float &intensity [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    
    float2 center = float2(0.5);
    float dist = length(in.texCoord - center);
    float vignette = 1.0 - smoothstep(0.3, 0.9, dist * intensity);
    
    color.rgb *= vignette;
    
    return color;
}

// MARK: - Noise Generation (for procedural textures)

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 noiseTextureShader(
    BloomVertexOut in [[stage_in]],
    constant float &time [[buffer(0)]]
) {
    float2 uv = in.texCoord * 10.0;
    
    float n = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    
    // Fractal noise
    for (int i = 0; i < 4; i++) {
        n += noise(uv * freq + time * 0.5) * amp;
        amp *= 0.5;
        freq *= 2.0;
    }
    
    return float4(float3(n * 0.5), 1.0);
}
