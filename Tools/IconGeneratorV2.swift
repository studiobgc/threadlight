#!/usr/bin/env swift

import Cocoa
import Metal
import MetalKit
import simd

// ═══════════════════════════════════════════════════════════════════════════
//  DIALOGUE EDITOR - EXPERIMENTAL GENERATIVE PSEUDO-3D ICON
//  Wild • Weird • Beautiful • Raw • GPU-Powered
// ═══════════════════════════════════════════════════════════════════════════

print("🎨 Generating EXPERIMENTAL pseudo-3D dock icon...")

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

guard let device = MTLCreateSystemDefaultDevice() else {
    print("❌ Metal not available")
    exit(1)
}

// Create iconset directory
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Unique seed based on timestamp for each build
let seed = Float(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10000))

// MARK: - Experimental Pseudo-3D Shader
let shaderSource = """
#include <metal_stdlib>
using namespace metal;

// Noise functions for organic feel
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
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

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

// Signed distance functions for 3D-like shapes
float sdSphere(float3 p, float r) {
    return length(p) - r;
}

float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Rotation matrix
float3x3 rotateY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        float3(c, 0, s),
        float3(0, 1, 0),
        float3(-s, 0, c)
    );
}

float3x3 rotateX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        float3(1, 0, 0),
        float3(0, c, -s),
        float3(0, s, c)
    );
}

// Scene SDF - dialogue bubbles floating in space
float sceneSDF(float3 p, float seed) {
    // Main rounded cube (dialogue box)
    float3 p1 = p;
    p1 = rotateY(seed * 0.1 + 0.3) * p1;
    p1 = rotateX(0.2) * p1;
    float mainBox = sdRoundBox(p1, float3(0.35, 0.25, 0.08), 0.08);
    
    // Floating smaller cubes (nodes)
    float3 p2 = p - float3(0.4, 0.35, -0.1);
    p2 = rotateY(seed * 0.15 + 1.0) * p2;
    float node1 = sdRoundBox(p2, float3(0.12, 0.1, 0.04), 0.03);
    
    float3 p3 = p - float3(-0.45, -0.3, 0.15);
    p3 = rotateY(seed * 0.12 - 0.5) * p3;
    float node2 = sdRoundBox(p3, float3(0.14, 0.08, 0.04), 0.03);
    
    float3 p4 = p - float3(0.3, -0.4, -0.05);
    p4 = rotateY(seed * 0.18) * p4;
    float node3 = sdRoundBox(p4, float3(0.1, 0.1, 0.04), 0.025);
    
    // Connection torus rings
    float3 pt = p - float3(0.15, 0.15, 0.0);
    pt = rotateX(1.2) * pt;
    float ring1 = sdTorus(pt, float2(0.15, 0.015));
    
    float3 pt2 = p - float3(-0.2, -0.1, 0.0);
    pt2 = rotateX(0.8) * rotateY(0.5) * pt2;
    float ring2 = sdTorus(pt2, float2(0.12, 0.012));
    
    // Combine
    float d = mainBox;
    d = min(d, node1);
    d = min(d, node2);
    d = min(d, node3);
    d = min(d, ring1);
    d = min(d, ring2);
    
    return d;
}

// Calculate normal via gradient
float3 calcNormal(float3 p, float seed) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        sceneSDF(p + e.xyy, seed) - sceneSDF(p - e.xyy, seed),
        sceneSDF(p + e.yxy, seed) - sceneSDF(p - e.yxy, seed),
        sceneSDF(p + e.yyx, seed) - sceneSDF(p - e.yyx, seed)
    ));
}

// Raymarching
float raymarch(float3 ro, float3 rd, float seed) {
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        float3 p = ro + rd * t;
        float d = sceneSDF(p, seed);
        if (d < 0.001) return t;
        if (t > 10.0) break;
        t += d;
    }
    return -1.0;
}

kernel void generateIcon(
    texture2d<float, access::write> output [[texture(0)]],
    uint2 gid [[thread_position_in_grid]],
    constant float &seed [[buffer(0)]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = (float2(gid) - size * 0.5) / min(size.x, size.y);
    
    // Flip Y for correct orientation
    uv.y = -uv.y;
    
    // Background - deep space gradient with noise
    float bgNoise = fbm(uv * 3.0 + seed * 0.1, 4);
    float3 bgColor = mix(
        float3(0.08, 0.06, 0.15),  // Deep purple-black
        float3(0.12, 0.08, 0.22),  // Slightly lighter
        bgNoise
    );
    
    // Add subtle stars
    float stars = pow(hash(uv * 500.0 + seed), 20.0);
    bgColor += stars * 0.3;
    
    // Camera setup - isometric-ish view
    float3 ro = float3(0.0, 0.0, 2.0);  // Camera position
    float3 rd = normalize(float3(uv, -1.0));  // Ray direction
    
    // Rotate camera slightly for interesting angle
    float3x3 camRot = rotateY(0.3) * rotateX(-0.15);
    rd = camRot * rd;
    ro = camRot * ro;
    
    // Raymarch the scene
    float t = raymarch(ro, rd, seed);
    
    float4 finalColor = float4(bgColor, 1.0);
    
    if (t > 0.0) {
        float3 p = ro + rd * t;
        float3 n = calcNormal(p, seed);
        
        // Lighting - three-point setup for drama
        float3 lightDir1 = normalize(float3(1.0, 1.0, 0.5));   // Key light
        float3 lightDir2 = normalize(float3(-0.5, 0.3, 0.8));  // Fill light
        float3 lightDir3 = normalize(float3(0.0, -1.0, 0.3));  // Rim light
        
        float diff1 = max(dot(n, lightDir1), 0.0);
        float diff2 = max(dot(n, lightDir2), 0.0);
        float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
        
        // Material colors - vibrant and experimental
        float3 baseColor;
        
        // Different colors for different parts based on position
        float colorMix = fbm(p.xy * 2.0 + seed * 0.05, 3);
        
        // Primary: electric purple to cyan gradient
        float3 color1 = float3(0.6, 0.2, 0.9);   // Purple
        float3 color2 = float3(0.2, 0.8, 0.9);   // Cyan
        float3 color3 = float3(0.9, 0.3, 0.5);   // Magenta
        
        baseColor = mix(color1, color2, colorMix);
        baseColor = mix(baseColor, color3, sin(p.y * 5.0 + seed) * 0.5 + 0.5);
        
        // Apply lighting
        float3 litColor = baseColor * 0.1;  // Ambient
        litColor += baseColor * diff1 * float3(1.0, 0.95, 0.9) * 0.7;  // Warm key
        litColor += baseColor * diff2 * float3(0.4, 0.5, 0.8) * 0.3;   // Cool fill
        litColor += float3(1.0, 0.8, 0.95) * rim * 0.5;                // Rim highlight
        
        // Add iridescence/holographic effect
        float iridescence = sin(dot(n, rd) * 10.0 + seed) * 0.5 + 0.5;
        litColor += float3(0.3, 0.5, 0.7) * iridescence * 0.15;
        
        // Fresnel glow
        float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 4.0);
        litColor += float3(0.5, 0.3, 0.9) * fresnel * 0.4;
        
        // Depth fog for atmosphere
        float fog = 1.0 - exp(-t * 0.3);
        litColor = mix(litColor, bgColor, fog * 0.3);
        
        // Ambient occlusion approximation
        float ao = 1.0 - smoothstep(0.0, 0.5, sceneSDF(p + n * 0.1, seed));
        litColor *= 0.5 + 0.5 * ao;
        
        finalColor = float4(litColor, 1.0);
    }
    
    // Vignette
    float vignette = 1.0 - length(uv) * 0.5;
    finalColor.rgb *= vignette;
    
    // Add chromatic aberration at edges for experimental feel
    float2 uvOffset = uv * 0.02 * length(uv);
    float chromaR = fbm((uv + uvOffset) * 5.0 + seed, 2);
    float chromaB = fbm((uv - uvOffset) * 5.0 + seed + 100.0, 2);
    finalColor.r += chromaR * 0.03;
    finalColor.b += chromaB * 0.03;
    
    // Subtle film grain
    float grain = hash(uv * 1000.0 + seed * 100.0) * 0.03;
    finalColor.rgb += grain;
    
    // Gamma correction
    finalColor.rgb = pow(finalColor.rgb, float3(1.0/2.2));
    
    // Clamp and output
    finalColor = clamp(finalColor, 0.0, 1.0);
    output.write(finalColor, gid);
}
"""

// Compile shader
let options = MTLCompileOptions()
let library: MTLLibrary
do {
    library = try device.makeLibrary(source: shaderSource, options: options)
} catch {
    print("❌ Shader compilation failed: \(error)")
    exit(1)
}

guard let function = library.makeFunction(name: "generateIcon"),
      let pipeline = try? device.makeComputePipelineState(function: function),
      let commandQueue = device.makeCommandQueue() else {
    print("❌ Failed to create pipeline")
    exit(1)
}

// Generate each size
for size in sizes {
    print("  Generating \(size)x\(size)...")
    
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: size,
        height: size,
        mipmapped: false
    )
    descriptor.usage = [.shaderRead, .shaderWrite]
    
    guard let texture = device.makeTexture(descriptor: descriptor),
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let encoder = commandBuffer.makeComputeCommandEncoder() else {
        continue
    }
    
    var seedValue = seed
    let seedBuffer = device.makeBuffer(bytes: &seedValue, length: MemoryLayout<Float>.size, options: .storageModeShared)
    
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(texture, index: 0)
    encoder.setBuffer(seedBuffer, offset: 0, index: 0)
    
    let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
    let threadgroups = MTLSize(
        width: (size + 7) / 8,
        height: (size + 7) / 8,
        depth: 1
    )
    encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
    encoder.endEncoding()
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    // Read back and save
    let bytesPerRow = size * 4
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    texture.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegion(origin: MTLOrigin(), size: MTLSize(width: size, height: size, depth: 1)), mipmapLevel: 0)
    
    // Create NSImage
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let cgImage = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        continue
    }
    
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    
    // Save as PNG
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        continue
    }
    
    let filename = "icon_\(size)x\(size).png"
    try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
    
    // Also save @2x versions for Retina
    if size <= 512 {
        let filename2x = "icon_\(size)x\(size)@2x.png"
        // For @2x, we'd need to generate at 2x size, but for simplicity, link to next size up
    }
}

print("✅ Generated iconset at: \(iconsetPath)")

// Convert to .icns using iconutil
print("🔨 Converting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon.icns"]

do {
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus == 0 {
        print("✅ Created AppIcon.icns")
    } else {
        print("⚠️  iconutil returned status \(process.terminationStatus)")
    }
} catch {
    print("❌ Failed to run iconutil: \(error)")
}
