#!/usr/bin/env swift

import Cocoa
import Metal
import MetalKit

/// MANTIA-INSPIRED GENERATIVE ICON SYSTEM
/// 
/// Philosophy (drawn from Louie Mantia's work):
/// - Icons should have DEPTH like real objects
/// - Materials should feel TANGIBLE (glass, metal, light)
/// - Metaphors should be CLEAR but ELEVATED
/// - Uniformity through the macOS squircle constraint
/// 
/// For a Dialogue Editor, the metaphor is:
/// - THE HUB: Central origin where all conversations begin
/// - BRANCHING PATHS: Neural/tree-like connections
/// - FLOW: Ideas cascading through the network
/// - CRYSTALLINE CLARITY: Clean, premium, thought made visible
///
/// This generator uses:
/// - Ray marching for true 3D depth
/// - Volumetric lighting for atmosphere
/// - SDF operations for crisp geometry
/// - Domain warping for organic feel
/// - Holographic/iridescent materials
/// - Multi-layer compositing

class ProceduralIconGenerator {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let computePipeline: MTLComputePipelineState
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw IconError.noMetalDevice
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw IconError.noCommandQueue
        }
        self.commandQueue = commandQueue
        
        let shaderSource = ProceduralIconGenerator.shaderSource
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        
        guard let function = library.makeFunction(name: "generateIcon") else {
            throw IconError.noFunction
        }
        
        self.computePipeline = try device.makeComputePipelineState(function: function)
    }
    
    func generate(size: Int, seed: Float = Float.random(in: 0...1000)) -> NSImage? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setTexture(texture, index: 0)
        
        var params = IconParams(
            seed: seed,
            time: Float(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)),
            size: Float(size)
        )
        computeEncoder.setBytes(&params, length: MemoryLayout<IconParams>.size, index: 0)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (size + 15) / 16,
            height: (size + 15) / 16,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return textureToImage(texture, size: size)
    }
    
    private func textureToImage(_ texture: MTLTexture, size: Int) -> NSImage? {
        let bytesPerRow = size * 4
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        
        texture.getBytes(
            &pixels,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                           size: MTLSize(width: size, height: size, depth: 1)),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
    
    struct IconParams {
        var seed: Float
        var time: Float
        var size: Float
    }
    
    enum IconError: Error {
        case noMetalDevice
        case noCommandQueue
        case noFunction
    }
    
    // MARK: - THE INSANE SHADER
    // Ray-marched 3D with volumetrics, holographic materials, and neural networks
    
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct IconParams {
        float seed;
        float time;
        float size;
    };
    
    // ============================================
    // NOISE & UTILITY FUNCTIONS
    // ============================================
    
    float hash(float2 p) {
        return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }
    
    float hash3(float3 p) {
        return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453);
    }
    
    float noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + float2(1,0)), f.x),
                   mix(hash(i + float2(0,1)), hash(i + float2(1,1)), f.x), f.y);
    }
    
    float noise3(float3 p) {
        float3 i = floor(p);
        float3 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(
            mix(mix(hash3(i), hash3(i + float3(1,0,0)), f.x),
                mix(hash3(i + float3(0,1,0)), hash3(i + float3(1,1,0)), f.x), f.y),
            mix(mix(hash3(i + float3(0,0,1)), hash3(i + float3(1,0,1)), f.x),
                mix(hash3(i + float3(0,1,1)), hash3(i + float3(1,1,1)), f.x), f.y), f.z);
    }
    
    float fbm(float2 p, float seed) {
        float v = 0.0, a = 0.5;
        float2 shift = float2(seed * 100.0);
        for (int i = 0; i < 5; i++) {
            v += a * noise(p + shift);
            p = p * 2.0 + shift;
            a *= 0.5;
        }
        return v;
    }
    
    float fbm3(float3 p) {
        float v = 0.0, a = 0.5;
        for (int i = 0; i < 4; i++) {
            v += a * noise3(p);
            p = p * 2.0;
            a *= 0.5;
        }
        return v;
    }
    
    // ============================================
    // SIGNED DISTANCE FUNCTIONS
    // ============================================
    
    float sdSphere(float3 p, float r) {
        return length(p) - r;
    }
    
    float sdBox(float3 p, float3 b) {
        float3 q = abs(p) - b;
        return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
    }
    
    float sdRoundBox(float3 p, float3 b, float r) {
        float3 q = abs(p) - b + r;
        return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
    }
    
    float sdCapsule(float3 p, float3 a, float3 b, float r) {
        float3 pa = p - a, ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        return length(pa - ba * h) - r;
    }
    
    float sdTorus(float3 p, float2 t) {
        float2 q = float2(length(p.xz) - t.x, p.y);
        return length(q) - t.y;
    }
    
    float sdRoundedBox2D(float2 p, float2 b, float r) {
        float2 q = abs(p) - b + r;
        return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
    }
    
    float opSmoothUnion(float d1, float d2, float k) {
        float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
        return mix(d2, d1, h) - k * h * (1.0 - h);
    }
    
    float opSmoothSubtraction(float d1, float d2, float k) {
        float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
        return mix(d2, -d1, h) + k * h * (1.0 - h);
    }
    
    // ============================================
    // THE DIALOGUE HUB - 3D SCENE
    // ============================================
    
    // Central crystalline hub with emanating neural branches
    float sceneDistance(float3 p, float seed) {
        float scene = 1e10;
        
        // === THE CENTRAL HUB ===
        // A faceted crystalline sphere - the origin of all dialogue
        float3 hubP = p;
        
        // Slight organic deformation
        float deform = fbm3(p * 3.0 + seed) * 0.08;
        float hub = sdSphere(hubP, 0.28 + deform);
        
        // Carve facets into the hub using intersecting planes
        for (int i = 0; i < 6; i++) {
            float angle = float(i) * 1.047 + seed * 0.1;
            float3 n = normalize(float3(cos(angle), sin(angle) * 0.5, sin(angle)));
            float facet = dot(hubP, n) - 0.22;
            hub = max(hub, facet);
        }
        scene = hub;
        
        // === INNER CORE ===
        // A glowing inner sphere
        float core = sdSphere(p, 0.12);
        scene = opSmoothUnion(scene, core, 0.05);
        
        // === ORBITAL RINGS ===
        // Three interlocking rings representing dialogue branches
        float3 ringP1 = p;
        float ring1 = sdTorus(ringP1, float2(0.45, 0.018));
        
        float3 ringP2 = float3(p.x, p.z, p.y); // rotated 90°
        float ring2 = sdTorus(ringP2, float2(0.42, 0.015));
        
        float3 ringP3 = float3(p.y, p.x, p.z);
        float ring3 = sdTorus(ringP3, float2(0.48, 0.012));
        
        scene = opSmoothUnion(scene, ring1, 0.02);
        scene = opSmoothUnion(scene, ring2, 0.02);
        scene = opSmoothUnion(scene, ring3, 0.02);
        
        // === NEURAL BRANCHES ===
        // Emanating connection lines
        for (int i = 0; i < 5; i++) {
            float angle = float(i) * 1.2566 + seed * 0.5;
            float3 dir = normalize(float3(cos(angle), sin(angle) * 0.3, sin(angle)));
            float3 start = dir * 0.3;
            float3 end = dir * 0.7;
            float branch = sdCapsule(p, start, end, 0.015 - float(i) * 0.002);
            scene = opSmoothUnion(scene, branch, 0.03);
            
            // Node at the end
            float node = sdSphere(p - end, 0.04);
            scene = opSmoothUnion(scene, node, 0.02);
        }
        
        // === FLOATING PARTICLES ===
        // Small orbiting thought fragments
        for (int i = 0; i < 8; i++) {
            float t = float(i) * 0.785 + seed;
            float r = 0.55 + sin(t * 2.0) * 0.1;
            float3 particlePos = float3(cos(t) * r, sin(t * 1.5) * 0.15, sin(t) * r);
            float particle = sdSphere(p - particlePos, 0.025);
            scene = opSmoothUnion(scene, particle, 0.01);
        }
        
        return scene;
    }
    
    // Calculate normal via gradient
    float3 calcNormal(float3 p, float seed) {
        float2 e = float2(0.001, 0.0);
        return normalize(float3(
            sceneDistance(p + e.xyy, seed) - sceneDistance(p - e.xyy, seed),
            sceneDistance(p + e.yxy, seed) - sceneDistance(p - e.yxy, seed),
            sceneDistance(p + e.yyx, seed) - sceneDistance(p - e.yyx, seed)
        ));
    }
    
    // ============================================
    // MATERIALS & LIGHTING
    // ============================================
    
    // Holographic/iridescent color based on view angle
    float3 holographic(float3 normal, float3 viewDir, float seed) {
        float fresnel = pow(1.0 - abs(dot(normal, viewDir)), 3.0);
        float angle = atan2(normal.y, normal.x) + seed;
        
        // Spectral color wheel
        float3 col1 = float3(0.486, 0.227, 0.929); // Purple
        float3 col2 = float3(0.063, 0.725, 0.906); // Cyan
        float3 col3 = float3(0.976, 0.420, 0.643); // Pink
        float3 col4 = float3(0.294, 0.910, 0.529); // Green
        
        float t = fract(angle / 6.283 + fresnel * 0.5);
        float3 holo;
        if (t < 0.25) holo = mix(col1, col2, t * 4.0);
        else if (t < 0.5) holo = mix(col2, col3, (t - 0.25) * 4.0);
        else if (t < 0.75) holo = mix(col3, col4, (t - 0.5) * 4.0);
        else holo = mix(col4, col1, (t - 0.75) * 4.0);
        
        return mix(float3(0.9), holo, fresnel * 0.7 + 0.3);
    }
    
    // Glass-like material with refraction hints
    float3 glassMaterial(float3 normal, float3 viewDir, float3 lightDir) {
        float NdotL = max(dot(normal, lightDir), 0.0);
        float NdotV = max(dot(normal, viewDir), 0.0);
        
        // Fresnel
        float fresnel = pow(1.0 - NdotV, 4.0);
        
        // Specular
        float3 halfVec = normalize(lightDir + viewDir);
        float spec = pow(max(dot(normal, halfVec), 0.0), 64.0);
        
        // Base glass color (slightly blue tinted)
        float3 glassColor = float3(0.85, 0.9, 0.95);
        
        // Rim lighting
        float rim = pow(1.0 - NdotV, 2.0);
        
        return glassColor * (0.3 + NdotL * 0.4) + float3(1.0) * spec * 0.8 + float3(0.6, 0.8, 1.0) * rim * 0.3 + fresnel * 0.2;
    }
    
    // ============================================
    // VOLUMETRIC EFFECTS
    // ============================================
    
    float3 volumetricGlow(float3 ro, float3 rd, float seed) {
        float3 glow = float3(0.0);
        float t = 0.0;
        
        for (int i = 0; i < 32; i++) {
            float3 p = ro + rd * t;
            float d = sceneDistance(p, seed);
            
            // Accumulate glow near surfaces
            float glowIntensity = 0.015 / (abs(d) + 0.02);
            
            // Color based on position
            float3 glowColor = mix(
                float3(0.486, 0.227, 0.929),  // Purple core
                float3(0.063, 0.725, 0.906),  // Cyan outer
                smoothstep(0.0, 0.5, length(p))
            );
            
            glow += glowColor * glowIntensity * 0.02;
            
            t += max(d * 0.5, 0.01);
            if (t > 2.0) break;
        }
        
        return glow;
    }
    
    // ============================================
    // RAY MARCHING
    // ============================================
    
    float4 rayMarch(float3 ro, float3 rd, float seed) {
        float t = 0.0;
        float3 col = float3(0.0);
        float alpha = 0.0;
        
        for (int i = 0; i < 80; i++) {
            float3 p = ro + rd * t;
            float d = sceneDistance(p, seed);
            
            if (d < 0.001) {
                // Hit! Calculate shading
                float3 normal = calcNormal(p, seed);
                float3 viewDir = -rd;
                float3 lightDir1 = normalize(float3(1.0, 1.0, 0.5));
                float3 lightDir2 = normalize(float3(-0.5, 0.3, 1.0));
                
                // Determine material based on distance from center
                float centerDist = length(p);
                
                if (centerDist < 0.15) {
                    // Inner core - pure glowing energy
                    col = float3(1.0, 0.9, 0.95) * 1.5;
                } else if (centerDist < 0.35) {
                    // Central hub - holographic crystal
                    col = holographic(normal, viewDir, seed);
                    col *= 0.8 + 0.2 * max(dot(normal, lightDir1), 0.0);
                    col += pow(max(dot(reflect(-lightDir1, normal), viewDir), 0.0), 32.0) * 0.5;
                } else {
                    // Outer structures - glass material
                    col = glassMaterial(normal, viewDir, lightDir1);
                    col += glassMaterial(normal, viewDir, lightDir2) * 0.3;
                }
                
                // Ambient occlusion approximation
                float ao = 1.0 - float(i) / 80.0;
                col *= ao;
                
                alpha = 1.0;
                break;
            }
            
            t += d;
            if (t > 3.0) break;
        }
        
        // Add volumetric glow
        col += volumetricGlow(ro, rd, seed) * (1.0 - alpha * 0.5);
        
        return float4(col, alpha);
    }
    
    // ============================================
    // MAIN KERNEL
    // ============================================
    
    kernel void generateIcon(
        texture2d<float, access::write> output [[texture(0)]],
        constant IconParams& params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(params.size);
        float2 uv = float2(gid) / size;
        float2 p = (uv - 0.5) * 2.0;
        
        // macOS Big Sur squircle mask
        float iconRadius = 0.22;
        float iconDist = sdRoundedBox2D(p, float2(0.85), iconRadius);
        
        if (iconDist > 0.015) {
            output.write(float4(0.0), gid);
            return;
        }
        
        // Camera setup
        float3 ro = float3(0.0, 0.0, 1.8);  // Camera position
        float3 target = float3(0.0, 0.0, 0.0);
        float3 forward = normalize(target - ro);
        float3 right = normalize(cross(float3(0.0, 1.0, 0.0), forward));
        float3 up = cross(forward, right);
        
        // Ray direction with slight fisheye for icon drama
        float2 screenP = p * 1.1;
        float3 rd = normalize(forward + screenP.x * right + screenP.y * up);
        
        // Render the 3D scene
        float4 sceneColor = rayMarch(ro, rd, params.seed);
        
        // === BACKGROUND ===
        // Deep space with subtle nebula
        float3 bgColor = float3(0.02, 0.015, 0.04);
        
        // Nebula clouds
        float2 wp = p * 3.0;
        float nebula = fbm(wp + params.seed, params.seed);
        float3 nebulaColor = mix(
            float3(0.15, 0.05, 0.2),
            float3(0.05, 0.1, 0.2),
            nebula
        );
        bgColor += nebulaColor * nebula * 0.3;
        
        // Stars
        float stars = pow(noise(uv * params.size * 0.3 + params.seed * 10.0), 12.0);
        bgColor += float3(1.0) * stars * 0.8;
        
        // Compose scene over background
        float3 col = mix(bgColor, sceneColor.rgb, sceneColor.a);
        
        // === POST PROCESSING ===
        
        // Vignette
        float vignette = 1.0 - dot(p * 0.6, p * 0.6);
        col *= vignette;
        
        // Edge glow (icon rim light)
        float edgeGlow = smoothstep(0.015, -0.08, iconDist);
        float3 rimColor = mix(
            float3(0.486, 0.227, 0.929),
            float3(0.063, 0.725, 0.906),
            fbm(p * 4.0, params.seed)
        );
        col += rimColor * edgeGlow * 0.4;
        
        // Subtle chromatic aberration at icon edge
        float chromaOffset = smoothstep(-0.1, 0.0, iconDist) * 0.01;
        col.r *= 1.0 + chromaOffset;
        col.b *= 1.0 - chromaOffset;
        
        // Tone mapping (ACES-ish)
        col = col / (col + 0.5);
        col = pow(col, float3(0.9));  // Slight gamma
        
        // Anti-aliased edge
        float alpha = 1.0 - smoothstep(-0.015, 0.015, iconDist);
        
        output.write(float4(col, alpha), gid);
    }
    """
}

// MARK: - Icon Set Generator

func generateIconSet(outputPath: String) {
    print("🎨 Generating procedural dock icon with Metal shaders...")
    
    do {
        let generator = try ProceduralIconGenerator()
        let seed = Float.random(in: 0...1000)
        
        // macOS icon sizes
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        
        // Create iconset directory
        let iconsetPath = "\(outputPath)/AppIcon.iconset"
        try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
        
        for size in sizes {
            print("  Generating \(size)x\(size)...")
            
            // 1x
            if let image = generator.generate(size: size, seed: seed) {
                let url = URL(fileURLWithPath: "\(iconsetPath)/icon_\(size)x\(size).png")
                savePNG(image: image, to: url)
            }
            
            // 2x (for retina)
            if size <= 512 {
                if let image = generator.generate(size: size * 2, seed: seed) {
                    let url = URL(fileURLWithPath: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
                    savePNG(image: image, to: url)
                }
            }
        }
        
        print("✅ Generated iconset at: \(iconsetPath)")
        print("🔨 Converting to .icns...")
        
        // Convert to icns using iconutil
        let icnsPath = "\(outputPath)/AppIcon.icns"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("✅ Created AppIcon.icns")
            print("📁 Keeping iconset for asset catalog use")
        } else {
            print("⚠️  iconutil failed, keeping iconset for manual conversion")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
}

func savePNG(image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    try? pngData.write(to: url)
}

// MARK: - Main

let outputPath = CommandLine.arguments.count > 1 
    ? CommandLine.arguments[1] 
    : FileManager.default.currentDirectoryPath

generateIconSet(outputPath: outputPath)
