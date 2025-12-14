#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Vertex input for node rendering
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
    vector_float4 color;
} NodeVertex;

// Per-node instance data for GPU instancing
typedef struct {
    matrix_float4x4 transform;
    vector_float4 backgroundColor;
    vector_float4 headerColor;
    vector_float4 borderColor;
    vector_float2 size;
    float cornerRadius;
    float borderWidth;
    float glowIntensity;
    float isSelected;
    float isHovered;
    float padding;
} NodeInstanceData;

// Connection vertex data
typedef struct {
    vector_float2 position;
    vector_float4 color;
    float progress;
    float thickness;
} ConnectionVertex;

// Uniforms shared across all shaders
typedef struct {
    matrix_float4x4 viewProjectionMatrix;
    vector_float2 viewportSize;
    float time;
    float zoom;
    vector_float2 pan;
    float padding1;
    float padding2;
} Uniforms;

// Grid rendering uniforms
typedef struct {
    vector_float4 minorGridColor;
    vector_float4 majorGridColor;
    vector_float4 backgroundColor;
    float minorGridSize;
    float majorGridSize;
    float zoom;
    float padding;
} GridUniforms;

// Particle data for effects
typedef struct {
    vector_float2 position;
    vector_float2 velocity;
    vector_float4 color;
    float size;
    float life;
    float maxLife;
    float padding;
} Particle;

// Bloom effect parameters
typedef struct {
    float threshold;
    float intensity;
    float radius;
    int iterations;
} BloomParams;

// Port rendering data
typedef struct {
    vector_float2 position;
    vector_float4 color;
    float radius;
    float isConnected;
    float isHovered;
    float glowIntensity;
} PortData;

// Buffer indices
typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1,
    BufferIndexInstances = 2,
    BufferIndexGridUniforms = 3,
    BufferIndexParticles = 4,
    BufferIndexBloomParams = 5,
} BufferIndex;

// Texture indices
typedef enum {
    TextureIndexColor = 0,
    TextureIndexBloom = 1,
    TextureIndexNoise = 2,
} TextureIndex;

#endif /* ShaderTypes_h */
