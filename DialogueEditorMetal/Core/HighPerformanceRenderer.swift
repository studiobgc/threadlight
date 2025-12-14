import Metal
import MetalKit
import simd

// MARK: - Figma-Level High Performance Rendering System
// 
// Key techniques from Figma research:
// 1. Retained mode with dirty rect tracking - only redraw what changed
// 2. GPU instancing - batch similar draw calls
// 3. Triple buffering - never wait for GPU
// 4. Input prediction - interpolate positions for sub-frame smoothness
// 5. Spatial indexing - O(log n) hit testing instead of O(n)
// 6. Tile-based rendering - only process visible tiles

// MARK: - Dirty Rect Tracking (Figma's key optimization)
class DirtyRectTracker {
    private var dirtyRects: [CGRect] = []
    private var fullRedrawNeeded = true
    
    func markDirty(_ rect: CGRect) {
        // Expand rect slightly for anti-aliasing
        let expanded = rect.insetBy(dx: -2, dy: -2)
        dirtyRects.append(expanded)
        
        // Merge overlapping rects to reduce draw calls
        mergeOverlappingRects()
    }
    
    func markFullRedraw() {
        fullRedrawNeeded = true
        dirtyRects.removeAll()
    }
    
    func needsFullRedraw() -> Bool {
        return fullRedrawNeeded
    }
    
    func getDirtyRects() -> [CGRect] {
        return dirtyRects
    }
    
    func clear() {
        dirtyRects.removeAll()
        fullRedrawNeeded = false
    }
    
    private func mergeOverlappingRects() {
        guard dirtyRects.count > 1 else { return }
        
        var merged = true
        while merged {
            merged = false
            var newRects: [CGRect] = []
            var used = Set<Int>()
            
            for i in 0..<dirtyRects.count {
                if used.contains(i) { continue }
                var current = dirtyRects[i]
                
                for j in (i+1)..<dirtyRects.count {
                    if used.contains(j) { continue }
                    if current.intersects(dirtyRects[j]) {
                        current = current.union(dirtyRects[j])
                        used.insert(j)
                        merged = true
                    }
                }
                newRects.append(current)
                used.insert(i)
            }
            dirtyRects = newRects
        }
        
        // If too many dirty rects, just do full redraw
        if dirtyRects.count > 10 {
            markFullRedraw()
        }
    }
}

// MARK: - Spatial Index for O(log n) Hit Testing (like Figma's R-tree)
class SpatialIndex<T: AnyObject> {
    private var items: [(bounds: CGRect, item: T)] = []
    private var gridCells: [[Int]] = []
    private var cellSize: CGFloat = 100
    private var gridWidth: Int = 0
    private var gridHeight: Int = 0
    private var origin: CGPoint = .zero
    
    func rebuild(items: [(bounds: CGRect, item: T)], viewportBounds: CGRect) {
        self.items = items
        
        // Create grid
        let expandedBounds = viewportBounds.insetBy(dx: -500, dy: -500)
        origin = expandedBounds.origin
        gridWidth = max(1, Int(ceil(expandedBounds.width / cellSize)))
        gridHeight = max(1, Int(ceil(expandedBounds.height / cellSize)))
        
        // Reset grid
        gridCells = Array(repeating: [], count: gridWidth * gridHeight)
        
        // Insert items into grid cells
        for (index, item) in items.enumerated() {
            let minX = max(0, Int((item.bounds.minX - origin.x) / cellSize))
            let maxX = min(gridWidth - 1, Int((item.bounds.maxX - origin.x) / cellSize))
            let minY = max(0, Int((item.bounds.minY - origin.y) / cellSize))
            let maxY = min(gridHeight - 1, Int((item.bounds.maxY - origin.y) / cellSize))
            
            for y in minY...maxY {
                for x in minX...maxX {
                    let cellIndex = y * gridWidth + x
                    if cellIndex >= 0 && cellIndex < gridCells.count {
                        gridCells[cellIndex].append(index)
                    }
                }
            }
        }
    }
    
    func query(point: CGPoint) -> T? {
        let cellX = Int((point.x - origin.x) / cellSize)
        let cellY = Int((point.y - origin.y) / cellSize)
        
        guard cellX >= 0 && cellX < gridWidth && cellY >= 0 && cellY < gridHeight else {
            return nil
        }
        
        let cellIndex = cellY * gridWidth + cellX
        guard cellIndex < gridCells.count else { return nil }
        
        // Check items in this cell (reverse order for z-order)
        for itemIndex in gridCells[cellIndex].reversed() {
            if items[itemIndex].bounds.contains(point) {
                return items[itemIndex].item
            }
        }
        return nil
    }
    
    func query(rect: CGRect) -> [T] {
        let minX = max(0, Int((rect.minX - origin.x) / cellSize))
        let maxX = min(gridWidth - 1, Int((rect.maxX - origin.x) / cellSize))
        let minY = max(0, Int((rect.minY - origin.y) / cellSize))
        let maxY = min(gridHeight - 1, Int((rect.maxY - origin.y) / cellSize))
        
        var foundIndices = Set<Int>()
        var results: [T] = []
        
        for y in minY...maxY {
            for x in minX...maxX {
                let cellIndex = y * gridWidth + x
                guard cellIndex < gridCells.count else { continue }
                
                for itemIndex in gridCells[cellIndex] {
                    if !foundIndices.contains(itemIndex) && items[itemIndex].bounds.intersects(rect) {
                        foundIndices.insert(itemIndex)
                        results.append(items[itemIndex].item)
                    }
                }
            }
        }
        return results
    }
}

// MARK: - Triple Buffering for Smooth 120fps
class TripleBuffer<T> {
    private var buffers: [T]
    private var currentIndex = 0
    private let semaphore = DispatchSemaphore(value: 3)
    
    init(createBuffer: () -> T) {
        buffers = [createBuffer(), createBuffer(), createBuffer()]
    }
    
    func nextBuffer() -> T {
        semaphore.wait()
        currentIndex = (currentIndex + 1) % 3
        return buffers[currentIndex]
    }
    
    func releaseBuffer() {
        semaphore.signal()
    }
}

// MARK: - Input Prediction for Sub-Frame Smoothness
class InputPredictor {
    private var positionHistory: [(time: CFTimeInterval, position: CGPoint)] = []
    private let historySize = 5
    
    func recordPosition(_ position: CGPoint) {
        let now = CACurrentMediaTime()
        positionHistory.append((now, position))
        
        // Keep only recent history
        if positionHistory.count > historySize {
            positionHistory.removeFirst()
        }
    }
    
    func predictPosition(at targetTime: CFTimeInterval) -> CGPoint {
        guard positionHistory.count >= 2 else {
            return positionHistory.last?.position ?? .zero
        }
        
        // Calculate velocity from recent samples
        let recent = positionHistory.suffix(3)
        var totalVelocity = CGPoint.zero
        var count: CGFloat = 0
        
        for i in 1..<recent.count {
            let prev = recent[recent.startIndex + i - 1]
            let curr = recent[recent.startIndex + i]
            let dt = curr.time - prev.time
            if dt > 0 {
                totalVelocity.x += (curr.position.x - prev.position.x) / CGFloat(dt)
                totalVelocity.y += (curr.position.y - prev.position.y) / CGFloat(dt)
                count += 1
            }
        }
        
        if count > 0 {
            totalVelocity.x /= count
            totalVelocity.y /= count
        }
        
        // Predict future position
        guard let lastSample = positionHistory.last else { return .zero }
        let dt = targetTime - lastSample.time
        
        // Apply damping for stability
        let damping: CGFloat = 0.8
        return CGPoint(
            x: lastSample.position.x + totalVelocity.x * CGFloat(dt) * damping,
            y: lastSample.position.y + totalVelocity.y * CGFloat(dt) * damping
        )
    }
    
    func clear() {
        positionHistory.removeAll()
    }
}

// MARK: - GPU Instance Buffer Manager
class InstanceBufferManager {
    private let device: MTLDevice
    private var nodeInstanceBuffer: MTLBuffer?
    private var connectionVertexBuffer: MTLBuffer?
    private var portInstanceBuffer: MTLBuffer?
    
    private let maxNodes = 10000
    private let maxConnectionVertices = 100000
    private let maxPorts = 50000
    
    // Triple buffering
    private var nodeBuffers: [MTLBuffer] = []
    private var connectionBuffers: [MTLBuffer] = []
    private var currentBufferIndex = 0
    
    init(device: MTLDevice) {
        self.device = device
        
        // Pre-allocate triple buffers
        for _ in 0..<3 {
            if let buffer = device.makeBuffer(length: MemoryLayout<NodeInstanceData>.stride * maxNodes, options: .storageModeShared) {
                nodeBuffers.append(buffer)
            }
            if let buffer = device.makeBuffer(length: MemoryLayout<ConnectionVertex>.stride * maxConnectionVertices, options: .storageModeShared) {
                connectionBuffers.append(buffer)
            }
        }
    }
    
    func nextNodeBuffer() -> MTLBuffer? {
        currentBufferIndex = (currentBufferIndex + 1) % 3
        return nodeBuffers.isEmpty ? nil : nodeBuffers[currentBufferIndex]
    }
    
    func nextConnectionBuffer() -> MTLBuffer? {
        return connectionBuffers.isEmpty ? nil : connectionBuffers[currentBufferIndex]
    }
    
    func updateNodeInstances(_ nodes: [DialogueNode], selectedIds: Set<UUID>, hoveredId: UUID?, viewportOffset: CGPoint, viewportZoom: CGFloat) -> (buffer: MTLBuffer, count: Int)? {
        guard let buffer = nextNodeBuffer() else { return nil }
        
        var instances: [NodeInstanceData] = []
        instances.reserveCapacity(nodes.count)
        
        for node in nodes {
            let isSelected = selectedIds.contains(node.id)
            let isHovered = hoveredId == node.id
            
            // Transform to screen space
            let screenX = Float(node.position.x * viewportZoom + viewportOffset.x)
            let screenY = Float(node.position.y * viewportZoom + viewportOffset.y)
            
            var transform = matrix_identity_float4x4
            transform.columns.3 = SIMD4<Float>(screenX, screenY, 0, 1)
            
            let instance = NodeInstanceData(
                transform: transform,
                backgroundColor: SIMD4<Float>(0.165, 0.165, 0.243, 1.0),
                headerColor: colorToSIMD4(node.nodeType.color),
                borderColor: isSelected ? SIMD4<Float>(0.486, 0.227, 0.929, 1.0) :
                            isHovered ? SIMD4<Float>(0.655, 0.545, 0.98, 1.0) :
                            SIMD4<Float>(0.29, 0.29, 0.416, 1.0),
                size: SIMD2<Float>(Float(node.size.width * viewportZoom), Float(node.size.height * viewportZoom)),
                cornerRadius: 10 * Float(viewportZoom),
                borderWidth: isSelected ? 3 : 2,
                glowIntensity: isSelected ? 1.0 : (isHovered ? 0.5 : 0.0),
                isSelected: isSelected ? 1.0 : 0.0,
                isHovered: isHovered ? 1.0 : 0.0,
                padding: 0
            )
            instances.append(instance)
        }
        
        // Copy to GPU buffer
        let dataSize = MemoryLayout<NodeInstanceData>.stride * instances.count
        memcpy(buffer.contents(), &instances, dataSize)
        
        return (buffer, instances.count)
    }
    
    private func colorToSIMD4(_ color: SwiftUI.Color) -> SIMD4<Float> {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.blue
        return SIMD4<Float>(
            Float(nsColor.redComponent),
            Float(nsColor.greenComponent),
            Float(nsColor.blueComponent),
            Float(nsColor.alphaComponent)
        )
    }
}

// MARK: - High Performance Render Loop
class HighPerformanceRenderLoop {
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 0
    
    private let renderQueue = DispatchQueue(label: "com.dialogueeditor.render", qos: .userInteractive)
    private let inputQueue = DispatchQueue(label: "com.dialogueeditor.input", qos: .userInteractive)
    
    var onRender: ((CFTimeInterval) -> Void)?
    var onInputProcess: (() -> Void)?
    
    func start() {
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let link = displayLink else { return }
        self.displayLink = link
        
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            let renderer = Unmanaged<HighPerformanceRenderLoop>.fromOpaque(userInfo!).takeUnretainedValue()
            renderer.frame()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        
        CVDisplayLinkStart(link)
        
        // Start high-frequency input processing (independent of render)
        startInputLoop()
    }
    
    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }
    
    private func frame() {
        let now = CACurrentMediaTime()
        let dt = now - lastFrameTime
        lastFrameTime = now
        
        // Calculate FPS
        frameCount += 1
        if frameCount % 60 == 0 {
            fps = 1.0 / dt
        }
        
        // Render on render queue
        renderQueue.async { [weak self] in
            self?.onRender?(dt)
        }
    }
    
    private func startInputLoop() {
        // Process input at 240Hz for ultra-responsive feel
        inputQueue.async { [weak self] in
            while true {
                self?.onInputProcess?()
                Thread.sleep(forTimeInterval: 1.0 / 240.0) // 240Hz input polling
            }
        }
    }
    
    func getCurrentFPS() -> Double {
        return fps
    }
}

// MARK: - Optimized Node Renderer with Batching
class BatchedNodeRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let instanceBuffer: InstanceBufferManager
    
    // Batch similar nodes together
    private var dialogueBatch: [Int] = []
    private var branchBatch: [Int] = []
    private var conditionBatch: [Int] = []
    private var otherBatch: [Int] = []
    
    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) throws {
        self.device = device
        self.instanceBuffer = InstanceBufferManager(device: device)
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "nodeVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "nodeFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func render(encoder: MTLRenderCommandEncoder, nodes: [DialogueNode], selectedIds: Set<UUID>, hoveredId: UUID?, viewportOffset: CGPoint, viewportZoom: CGFloat) {
        guard !nodes.isEmpty else { return }
        
        // Update instance buffer with all nodes
        guard let (buffer, count) = instanceBuffer.updateNodeInstances(nodes, selectedIds: selectedIds, hoveredId: hoveredId, viewportOffset: viewportOffset, viewportZoom: viewportZoom) else { return }
        
        // Single instanced draw call for ALL nodes
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 1)
        
        // Draw all nodes in one call (GPU instancing)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: count)
    }
}

import SwiftUI

// Note: NodeInstanceData and ConnectionVertex are defined in NodeGraphRenderer.swift
