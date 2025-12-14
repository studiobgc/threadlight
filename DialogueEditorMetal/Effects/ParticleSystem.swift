import MetalKit
import simd

class ParticleSystem {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState!
    private var particleBuffer: MTLBuffer!
    
    private let maxParticles = 10000
    private var activeParticles = 0
    private var particles: [ParticleData] = []
    
    struct ParticleData {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var color: SIMD4<Float>
        var size: Float
        var life: Float
        var maxLife: Float
        var padding: Float = 0
    }
    
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        // Setup compute pipeline for particle physics
        if let updateFunction = library.makeFunction(name: "updateParticles") {
            computePipelineState = try? device.makeComputePipelineState(function: updateFunction)
        }
        
        // Allocate particle buffer
        particleBuffer = device.makeBuffer(
            length: MemoryLayout<ParticleData>.stride * maxParticles,
            options: .storageModeShared
        )
        
        particles = Array(repeating: ParticleData(
            position: .zero,
            velocity: .zero,
            color: .zero,
            size: 0,
            life: 0,
            maxLife: 0
        ), count: maxParticles)
    }
    
    // MARK: - Emitters
    
    func emitBurst(at position: CGPoint, count: Int, color: SIMD4<Float>, spread: Float = 100) {
        for _ in 0..<min(count, maxParticles - activeParticles) {
            let angle = Float.random(in: 0...(2 * .pi))
            let speed = Float.random(in: 50...150)
            
            let particle = ParticleData(
                position: SIMD2<Float>(Float(position.x), Float(position.y)),
                velocity: SIMD2<Float>(cos(angle) * speed, sin(angle) * speed),
                color: color,
                size: Float.random(in: 2...6),
                life: Float.random(in: 0.5...1.5),
                maxLife: 1.5
            )
            
            if activeParticles < maxParticles {
                particles[activeParticles] = particle
                activeParticles += 1
            }
        }
        
        updateBuffer()
    }
    
    func emitConnectionSpark(from: CGPoint, to: CGPoint, color: SIMD4<Float>) {
        // Emit particles along a connection line
        let steps = 5
        for i in 0..<steps {
            let t = Float(i) / Float(steps - 1)
            let x = Float(from.x) + (Float(to.x) - Float(from.x)) * t
            let y = Float(from.y) + (Float(to.y) - Float(from.y)) * t
            
            let particle = ParticleData(
                position: SIMD2<Float>(x, y),
                velocity: SIMD2<Float>(Float.random(in: -30...30), Float.random(in: (-50)...(-20))),
                color: color,
                size: Float.random(in: 3...5),
                life: Float.random(in: 0.3...0.6),
                maxLife: 0.6
            )
            
            if activeParticles < maxParticles {
                particles[activeParticles] = particle
                activeParticles += 1
            }
        }
        
        updateBuffer()
    }
    
    func emitSelectionGlow(around rect: CGRect, color: SIMD4<Float>) {
        // Emit particles around a selection rectangle
        let perimeter = 2 * (rect.width + rect.height)
        let particleCount = Int(perimeter / 20)
        
        for i in 0..<particleCount {
            let t = Float(i) / Float(particleCount)
            var pos: SIMD2<Float>
            
            let totalLength = Float(perimeter)
            let progress = t * totalLength
            
            if progress < Float(rect.width) {
                // Top edge
                pos = SIMD2<Float>(Float(rect.minX) + progress, Float(rect.minY))
            } else if progress < Float(rect.width + rect.height) {
                // Right edge
                let edgeProgress = progress - Float(rect.width)
                pos = SIMD2<Float>(Float(rect.maxX), Float(rect.minY) + edgeProgress)
            } else if progress < Float(2 * rect.width + rect.height) {
                // Bottom edge
                let edgeProgress = progress - Float(rect.width + rect.height)
                pos = SIMD2<Float>(Float(rect.maxX) - edgeProgress, Float(rect.maxY))
            } else {
                // Left edge
                let edgeProgress = progress - Float(2 * rect.width + rect.height)
                pos = SIMD2<Float>(Float(rect.minX), Float(rect.maxY) - edgeProgress)
            }
            
            let particle = ParticleData(
                position: pos,
                velocity: SIMD2<Float>(Float.random(in: -10...10), Float.random(in: -20...0)),
                color: color.withAlpha(Float.random(in: 0.3...0.8)),
                size: Float.random(in: 2...4),
                life: Float.random(in: 0.5...1.0),
                maxLife: 1.0
            )
            
            if activeParticles < maxParticles {
                particles[activeParticles] = particle
                activeParticles += 1
            }
        }
        
        updateBuffer()
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float, gravity: SIMD2<Float> = SIMD2<Float>(0, 50)) {
        guard let computePipelineState = computePipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            // Fallback to CPU update
            updateCPU(deltaTime: deltaTime, gravity: gravity)
            return
        }
        
        var dt = deltaTime
        var grav = gravity
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&dt, length: MemoryLayout<Float>.size, index: 1)
        computeEncoder.setBytes(&grav, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (activeParticles + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back and remove dead particles
        readBackAndCleanup()
    }
    
    private func updateCPU(deltaTime: Float, gravity: SIMD2<Float>) {
        var i = 0
        while i < activeParticles {
            particles[i].life -= deltaTime
            
            if particles[i].life <= 0 {
                // Remove particle by swapping with last
                particles[i] = particles[activeParticles - 1]
                activeParticles -= 1
            } else {
                // Update physics
                particles[i].velocity += gravity * deltaTime
                particles[i].position += particles[i].velocity * deltaTime
                particles[i].color.w = particles[i].life / particles[i].maxLife
                particles[i].size *= 0.99
                i += 1
            }
        }
        
        updateBuffer()
    }
    
    private func readBackAndCleanup() {
        let ptr = particleBuffer.contents().bindMemory(to: ParticleData.self, capacity: maxParticles)
        
        var i = 0
        while i < activeParticles {
            particles[i] = ptr[i]
            
            if particles[i].life <= 0 {
                particles[i] = particles[activeParticles - 1]
                activeParticles -= 1
            } else {
                i += 1
            }
        }
    }
    
    private func updateBuffer() {
        memcpy(particleBuffer.contents(), &particles, MemoryLayout<ParticleData>.stride * activeParticles)
    }
    
    // MARK: - Rendering
    
    func getBuffer() -> MTLBuffer {
        return particleBuffer
    }
    
    func getParticleCount() -> Int {
        return activeParticles
    }
    
    func clear() {
        activeParticles = 0
    }
}

// MARK: - SIMD Extensions

extension SIMD4 where Scalar == Float {
    func withAlpha(_ alpha: Float) -> SIMD4<Float> {
        return SIMD4<Float>(x, y, z, alpha)
    }
}
