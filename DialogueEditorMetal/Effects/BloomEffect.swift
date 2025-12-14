import MetalKit
import simd

class BloomEffect {
    private let device: MTLDevice
    
    // Pipeline states
    private var thresholdPipelineState: MTLRenderPipelineState!
    private var blurHPipelineState: MTLRenderPipelineState!
    private var blurVPipelineState: MTLRenderPipelineState!
    private var compositePipelineState: MTLRenderPipelineState!
    
    // Textures
    private var brightnessTexture: MTLTexture?
    private var blurTexture1: MTLTexture?
    private var blurTexture2: MTLTexture?
    
    // Parameters
    var threshold: Float = 0.8
    var intensity: Float = 0.5
    var radius: Float = 2.0
    var iterations: Int = 3
    
    private var textureSize: CGSize = .zero
    
    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        self.device = device
        setupPipelines(library: library, pixelFormat: pixelFormat)
    }
    
    private func setupPipelines(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        let vertexFunction = library.makeFunction(name: "bloomVertexShader")
        
        // Threshold pipeline
        let thresholdDescriptor = MTLRenderPipelineDescriptor()
        thresholdDescriptor.vertexFunction = vertexFunction
        thresholdDescriptor.fragmentFunction = library.makeFunction(name: "bloomThresholdShader")
        thresholdDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        thresholdPipelineState = try? device.makeRenderPipelineState(descriptor: thresholdDescriptor)
        
        // Horizontal blur pipeline
        let blurHDescriptor = MTLRenderPipelineDescriptor()
        blurHDescriptor.vertexFunction = vertexFunction
        blurHDescriptor.fragmentFunction = library.makeFunction(name: "bloomBlurHShader")
        blurHDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        blurHPipelineState = try? device.makeRenderPipelineState(descriptor: blurHDescriptor)
        
        // Vertical blur pipeline
        let blurVDescriptor = MTLRenderPipelineDescriptor()
        blurVDescriptor.vertexFunction = vertexFunction
        blurVDescriptor.fragmentFunction = library.makeFunction(name: "bloomBlurVShader")
        blurVDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        blurVPipelineState = try? device.makeRenderPipelineState(descriptor: blurVDescriptor)
        
        // Composite pipeline
        let compositeDescriptor = MTLRenderPipelineDescriptor()
        compositeDescriptor.vertexFunction = vertexFunction
        compositeDescriptor.fragmentFunction = library.makeFunction(name: "bloomCompositeShader")
        compositeDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        compositeDescriptor.colorAttachments[0].isBlendingEnabled = true
        compositeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        compositeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        compositePipelineState = try? device.makeRenderPipelineState(descriptor: compositeDescriptor)
    }
    
    func resize(to size: CGSize) {
        guard size != textureSize else { return }
        textureSize = size
        
        // Create bloom textures at half resolution for performance
        let bloomWidth = Int(size.width / 2)
        let bloomHeight = Int(size.height / 2)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: bloomWidth,
            height: bloomHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .private
        
        brightnessTexture = device.makeTexture(descriptor: textureDescriptor)
        blurTexture1 = device.makeTexture(descriptor: textureDescriptor)
        blurTexture2 = device.makeTexture(descriptor: textureDescriptor)
    }
    
    func apply(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture
    ) {
        guard let brightnessTexture = brightnessTexture,
              let blurTexture1 = blurTexture1,
              let blurTexture2 = blurTexture2,
              let thresholdPipelineState = thresholdPipelineState,
              let blurHPipelineState = blurHPipelineState,
              let blurVPipelineState = blurVPipelineState,
              let compositePipelineState = compositePipelineState else {
            return
        }
        
        var params = BloomParameters(
            threshold: threshold,
            intensity: intensity,
            radius: radius,
            iterations: Int32(iterations)
        )
        
        // Pass 1: Extract bright pixels
        let thresholdDescriptor = MTLRenderPassDescriptor()
        thresholdDescriptor.colorAttachments[0].texture = brightnessTexture
        thresholdDescriptor.colorAttachments[0].loadAction = .clear
        thresholdDescriptor.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: thresholdDescriptor) {
            encoder.setRenderPipelineState(thresholdPipelineState)
            encoder.setFragmentTexture(sourceTexture, index: 0)
            encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParameters>.size, index: 5)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }
        
        // Pass 2-N: Blur iterations
        var currentSource = brightnessTexture
        var currentDest = blurTexture1
        
        for i in 0..<iterations {
            // Horizontal blur
            let blurHDescriptor = MTLRenderPassDescriptor()
            blurHDescriptor.colorAttachments[0].texture = currentDest
            blurHDescriptor.colorAttachments[0].loadAction = .clear
            blurHDescriptor.colorAttachments[0].storeAction = .store
            
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurHDescriptor) {
                encoder.setRenderPipelineState(blurHPipelineState)
                encoder.setFragmentTexture(currentSource, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParameters>.size, index: 5)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()
            }
            
            // Swap
            let temp = currentSource
            currentSource = currentDest
            currentDest = (i % 2 == 0) ? blurTexture2 : blurTexture1
            
            // Vertical blur
            let blurVDescriptor = MTLRenderPassDescriptor()
            blurVDescriptor.colorAttachments[0].texture = currentDest
            blurVDescriptor.colorAttachments[0].loadAction = .clear
            blurVDescriptor.colorAttachments[0].storeAction = .store
            
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurVDescriptor) {
                encoder.setRenderPipelineState(blurVPipelineState)
                encoder.setFragmentTexture(currentSource, index: 0)
                encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParameters>.size, index: 5)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.endEncoding()
            }
            
            // Swap again
            let temp2 = currentSource
            currentSource = currentDest
            currentDest = temp2
        }
        
        // Final pass: Composite bloom onto destination
        let compositeDescriptor = MTLRenderPassDescriptor()
        compositeDescriptor.colorAttachments[0].texture = destinationTexture
        compositeDescriptor.colorAttachments[0].loadAction = .load
        compositeDescriptor.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: compositeDescriptor) {
            encoder.setRenderPipelineState(compositePipelineState)
            encoder.setFragmentTexture(sourceTexture, index: 0)
            encoder.setFragmentTexture(currentSource, index: 1)
            encoder.setFragmentBytes(&params, length: MemoryLayout<BloomParameters>.size, index: 5)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }
    }
}

struct BloomParameters {
    var threshold: Float
    var intensity: Float
    var radius: Float
    var iterations: Int32
}

// MARK: - Additional Post-Processing Effects

class GlowEffect {
    private let device: MTLDevice
    private var glowPipelineState: MTLRenderPipelineState?
    
    struct GlowParameters {
        var color: SIMD4<Float>
        var intensity: Float
        var radius: Float
        var falloff: Float
        var padding: Float = 0
    }
    
    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        self.device = device
        // Would setup glow-specific shaders here
    }
    
    func applyGlow(
        commandBuffer: MTLCommandBuffer,
        texture: MTLTexture,
        glowColor: SIMD4<Float>,
        intensity: Float,
        radius: Float
    ) {
        // Implementation would render glow effect
    }
}

class AmbientOcclusionEffect {
    private let device: MTLDevice
    private var aoPipelineState: MTLRenderPipelineState?
    
    struct AOParameters {
        var radius: Float
        var bias: Float
        var intensity: Float
        var samples: Int32
    }
    
    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        self.device = device
        // Would setup AO-specific shaders here
    }
    
    func apply(
        commandBuffer: MTLCommandBuffer,
        depthTexture: MTLTexture,
        normalTexture: MTLTexture,
        outputTexture: MTLTexture
    ) {
        // Implementation would compute screen-space ambient occlusion
    }
}

// MARK: - Animated Effects Controller

class EffectsController: ObservableObject {
    let device: MTLDevice
    var particleSystem: ParticleSystem?
    var bloomEffect: BloomEffect?
    var glowEffect: GlowEffect?
    
    @Published var bloomEnabled = true
    @Published var bloomThreshold: Float = 0.7
    @Published var bloomIntensity: Float = 0.4
    
    @Published var particlesEnabled = true
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func setup(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        particleSystem = ParticleSystem(device: device, library: library)
        bloomEffect = BloomEffect(device: device, library: library, pixelFormat: pixelFormat)
        glowEffect = GlowEffect(device: device, library: library, pixelFormat: pixelFormat)
    }
    
    func update(deltaTime: Float) {
        particleSystem?.update(deltaTime: deltaTime)
    }
    
    // MARK: - Event-triggered effects
    
    func onNodeSelected(at position: CGPoint) {
        guard particlesEnabled else { return }
        particleSystem?.emitBurst(
            at: position,
            count: 20,
            color: SIMD4<Float>(0.486, 0.227, 0.929, 1.0), // Purple
            spread: 50
        )
    }
    
    func onConnectionCreated(from: CGPoint, to: CGPoint) {
        guard particlesEnabled else { return }
        particleSystem?.emitConnectionSpark(
            from: from,
            to: to,
            color: SIMD4<Float>(0.494, 0.827, 0.129, 1.0) // Green
        )
    }
    
    func onNodeCreated(at position: CGPoint, color: SIMD4<Float>) {
        guard particlesEnabled else { return }
        particleSystem?.emitBurst(
            at: position,
            count: 30,
            color: color,
            spread: 80
        )
    }
}
