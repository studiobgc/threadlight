import MetalKit
import simd
import SwiftUI
import AppKit

class NodeGraphRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Pipeline states
    private var gridPipelineState: MTLRenderPipelineState!
    private var nodePipelineState: MTLRenderPipelineState!
    private var connectionPipelineState: MTLRenderPipelineState!
    private var connectionPreviewPipelineState: MTLRenderPipelineState!
    private var portPipelineState: MTLRenderPipelineState!
    private var selectionBoxPipelineState: MTLRenderPipelineState!
    
    // Bloom effect pipelines
    private var bloomThresholdPipelineState: MTLRenderPipelineState!
    private var bloomBlurHPipelineState: MTLRenderPipelineState!
    private var bloomBlurVPipelineState: MTLRenderPipelineState!
    private var bloomCompositePipelineState: MTLRenderPipelineState!
    
    // Buffers
    private var uniformsBuffer: MTLBuffer!
    private var gridUniformsBuffer: MTLBuffer!
    private var nodeVertexBuffer: MTLBuffer!
    private var nodeInstanceBuffer: MTLBuffer!
    private var connectionVertexBuffer: MTLBuffer!
    private var portInstanceBuffer: MTLBuffer!
    private var quadVertexBuffer: MTLBuffer!
    
    // Textures for effects
    private var bloomTexture1: MTLTexture?
    private var bloomTexture2: MTLTexture?
    
    // State
    var viewportSize: CGSize = .zero
    private var time: Float = 0
    
    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.library = device.makeDefaultLibrary()!
        
        setupPipelines(pixelFormat: pixelFormat)
        setupBuffers()
    }
    
    private func setupPipelines(pixelFormat: MTLPixelFormat) {
        // Grid pipeline
        let gridVertexFunction = library.makeFunction(name: "gridVertexShader")
        let gridFragmentFunction = library.makeFunction(name: "gridFragmentShader")
        
        let gridPipelineDescriptor = MTLRenderPipelineDescriptor()
        gridPipelineDescriptor.vertexFunction = gridVertexFunction
        gridPipelineDescriptor.fragmentFunction = gridFragmentFunction
        gridPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        gridPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        gridPipelineDescriptor.sampleCount = 4
        
        gridPipelineState = try! device.makeRenderPipelineState(descriptor: gridPipelineDescriptor)
        
        // Node pipeline
        let nodeVertexFunction = library.makeFunction(name: "nodeVertexShader")
        let nodeFragmentFunction = library.makeFunction(name: "nodeFragmentShader")
        
        let nodePipelineDescriptor = MTLRenderPipelineDescriptor()
        nodePipelineDescriptor.vertexFunction = nodeVertexFunction
        nodePipelineDescriptor.fragmentFunction = nodeFragmentFunction
        nodePipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        nodePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        nodePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        nodePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        nodePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        nodePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        nodePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        nodePipelineDescriptor.sampleCount = 4
        
        nodePipelineState = try! device.makeRenderPipelineState(descriptor: nodePipelineDescriptor)
        
        // Connection pipeline
        let connectionVertexFunction = library.makeFunction(name: "connectionVertexShader")
        let connectionFragmentFunction = library.makeFunction(name: "connectionFragmentShader")
        
        let connectionPipelineDescriptor = MTLRenderPipelineDescriptor()
        connectionPipelineDescriptor.vertexFunction = connectionVertexFunction
        connectionPipelineDescriptor.fragmentFunction = connectionFragmentFunction
        connectionPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        connectionPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        connectionPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        connectionPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        connectionPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        connectionPipelineDescriptor.sampleCount = 4
        
        connectionPipelineState = try! device.makeRenderPipelineState(descriptor: connectionPipelineDescriptor)
        
        // Connection preview pipeline (dashed)
        let connectionPreviewFragmentFunction = library.makeFunction(name: "connectionPreviewFragmentShader")
        
        let connectionPreviewDescriptor = MTLRenderPipelineDescriptor()
        connectionPreviewDescriptor.vertexFunction = connectionVertexFunction
        connectionPreviewDescriptor.fragmentFunction = connectionPreviewFragmentFunction
        connectionPreviewDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        connectionPreviewDescriptor.colorAttachments[0].isBlendingEnabled = true
        connectionPreviewDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        connectionPreviewDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        connectionPreviewDescriptor.depthAttachmentPixelFormat = .depth32Float
        connectionPreviewDescriptor.sampleCount = 4
        
        connectionPreviewPipelineState = try! device.makeRenderPipelineState(descriptor: connectionPreviewDescriptor)
        
        // Port pipeline
        let portVertexFunction = library.makeFunction(name: "portVertexShader")
        let portFragmentFunction = library.makeFunction(name: "portFragmentShader")
        
        let portPipelineDescriptor = MTLRenderPipelineDescriptor()
        portPipelineDescriptor.vertexFunction = portVertexFunction
        portPipelineDescriptor.fragmentFunction = portFragmentFunction
        portPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        portPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        portPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        portPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        portPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        portPipelineDescriptor.sampleCount = 4
        
        portPipelineState = try! device.makeRenderPipelineState(descriptor: portPipelineDescriptor)
        
        // Selection box pipeline
        let selectionVertexFunction = library.makeFunction(name: "selectionBoxVertexShader")
        let selectionFragmentFunction = library.makeFunction(name: "selectionBoxFragmentShader")
        
        let selectionPipelineDescriptor = MTLRenderPipelineDescriptor()
        selectionPipelineDescriptor.vertexFunction = selectionVertexFunction
        selectionPipelineDescriptor.fragmentFunction = selectionFragmentFunction
        selectionPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        selectionPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        selectionPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        selectionPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        selectionPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        selectionPipelineDescriptor.sampleCount = 4
        
        selectionBoxPipelineState = try! device.makeRenderPipelineState(descriptor: selectionPipelineDescriptor)
    }
    
    private func setupBuffers() {
        // Node quad vertices (unit quad, transformed per-instance)
        let nodeVertices: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1),
            SIMD2(0, 1), SIMD2(1, 0), SIMD2(1, 1)
        ]
        nodeVertexBuffer = device.makeBuffer(
            bytes: nodeVertices,
            length: MemoryLayout<SIMD2<Float>>.stride * nodeVertices.count,
            options: .storageModeShared
        )
        
        // Port quad vertices (centered unit quad)
        let quadVertices: [SIMD2<Float>] = [
            SIMD2(-0.5, -0.5), SIMD2(0.5, -0.5), SIMD2(-0.5, 0.5),
            SIMD2(-0.5, 0.5), SIMD2(0.5, -0.5), SIMD2(0.5, 0.5)
        ]
        quadVertexBuffer = device.makeBuffer(
            bytes: quadVertices,
            length: MemoryLayout<SIMD2<Float>>.stride * quadVertices.count,
            options: .storageModeShared
        )
        
        // Pre-allocate instance buffers
        nodeInstanceBuffer = device.makeBuffer(length: MemoryLayout<NodeInstanceData>.stride * 1000, options: .storageModeShared)
        connectionVertexBuffer = device.makeBuffer(length: MemoryLayout<ConnectionVertex>.stride * 10000, options: .storageModeShared)
        portInstanceBuffer = device.makeBuffer(length: MemoryLayout<PortData>.stride * 5000, options: .storageModeShared)
        
        // Uniform buffers
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
        gridUniformsBuffer = device.makeBuffer(length: MemoryLayout<GridUniforms>.stride, options: .storageModeShared)
    }
    
    func render(
        in view: MTKView,
        nodes: [DialogueNode],
        connections: [Connection],
        viewportOffset: CGPoint,
        viewportZoom: CGFloat,
        selectedNodeIds: Set<UUID>,
        hoveredNodeId: UUID?,
        connectionPreview: ConnectionPreview?,
        selectionBox: (CGPoint, CGPoint)?
    ) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        viewportSize = view.drawableSize
        time += 1.0 / 120.0
        
        // Update uniforms
        updateUniforms(viewportOffset: viewportOffset, viewportZoom: viewportZoom)
        
        // Begin render pass
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // 1. Draw grid
        renderGrid(encoder: renderEncoder)
        
        // 2. Draw connections
        renderConnections(encoder: renderEncoder, connections: connections, nodes: nodes)
        
        // 3. Draw connection preview
        if let preview = connectionPreview {
            renderConnectionPreview(encoder: renderEncoder, preview: preview)
        }
        
        // 4. Draw nodes
        renderNodes(encoder: renderEncoder, nodes: nodes, selectedNodeIds: selectedNodeIds, hoveredNodeId: hoveredNodeId)
        
        // 5. Draw ports
        renderPorts(encoder: renderEncoder, nodes: nodes, connections: connections, hoveredNodeId: hoveredNodeId)
        
        // 6. Draw selection box
        if let box = selectionBox {
            renderSelectionBox(encoder: renderEncoder, start: box.0, end: box.1)
        }
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateUniforms(viewportOffset: CGPoint, viewportZoom: CGFloat) {
        var uniforms = Uniforms(
            viewProjectionMatrix: createViewProjectionMatrix(width: Float(viewportSize.width), height: Float(viewportSize.height), zoom: Float(viewportZoom), panX: Float(viewportOffset.x), panY: Float(viewportOffset.y)),
            viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
            time: time,
            zoom: Float(viewportZoom),
            pan: SIMD2<Float>(Float(viewportOffset.x), Float(viewportOffset.y)),
            padding1: 0,
            padding2: 0
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
        
        var gridUniforms = GridUniforms(
            minorGridColor: SIMD4<Float>(0.29, 0.29, 0.42, 1.0),
            majorGridColor: SIMD4<Float>(0.212, 0.212, 0.322, 1.0),
            backgroundColor: SIMD4<Float>(0.118, 0.118, 0.180, 1.0),
            minorGridSize: 20,
            majorGridSize: 100,
            zoom: Float(viewportZoom),
            padding: 0
        )
        memcpy(gridUniformsBuffer.contents(), &gridUniforms, MemoryLayout<GridUniforms>.stride)
    }
    
    private func renderGrid(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(gridPipelineState)
        encoder.setFragmentBuffer(gridUniformsBuffer, offset: 0, index: Int(BufferIndexGridUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    private func renderNodes(
        encoder: MTLRenderCommandEncoder,
        nodes: [DialogueNode],
        selectedNodeIds: Set<UUID>,
        hoveredNodeId: UUID?
    ) {
        guard !nodes.isEmpty else { return }
        
        // Build instance data
        var instances: [NodeInstanceData] = []
        
        for node in nodes {
            let transform = matrix4x4_translation(Float(node.position.x), Float(node.position.y), 0)
            let nodeColor = colorToSIMD4(node.nodeType.color)
            let isSelected = selectedNodeIds.contains(node.id)
            let isHovered = hoveredNodeId == node.id
            
            let instance = NodeInstanceData(
                transform: transform,
                backgroundColor: SIMD4<Float>(0.165, 0.165, 0.243, 1.0),
                headerColor: nodeColor,
                borderColor: isSelected ? SIMD4<Float>(0.486, 0.227, 0.929, 1.0) :
                            isHovered ? SIMD4<Float>(0.655, 0.545, 0.98, 1.0) :
                            SIMD4<Float>(0.29, 0.29, 0.416, 1.0),
                size: SIMD2<Float>(Float(node.size.width), Float(node.size.height)),
                cornerRadius: 10,
                borderWidth: isSelected ? 3 : 2,
                glowIntensity: isSelected ? 1.0 : 0.0,
                isSelected: isSelected ? 1.0 : 0.0,
                isHovered: isHovered ? 1.0 : 0.0,
                padding: 0
            )
            instances.append(instance)
        }
        
        // Update buffer
        memcpy(nodeInstanceBuffer.contents(), &instances, MemoryLayout<NodeInstanceData>.stride * instances.count)
        
        encoder.setRenderPipelineState(nodePipelineState)
        encoder.setVertexBuffer(nodeVertexBuffer, offset: 0, index: Int(BufferIndexVertices.rawValue))
        encoder.setVertexBuffer(nodeInstanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
    }
    
    private func renderConnections(
        encoder: MTLRenderCommandEncoder,
        connections: [Connection],
        nodes: [DialogueNode]
    ) {
        guard !connections.isEmpty else { return }
        
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var vertices: [ConnectionVertex] = []
        
        for connection in connections {
            guard let fromNode = nodeMap[connection.fromNodeId],
                  let toNode = nodeMap[connection.toNodeId] else {
                continue
            }
            
            let fromPos = fromNode.getPortPosition(type: .output, index: connection.fromPortIndex)
            let toPos = toNode.getPortPosition(type: .input, index: connection.toPortIndex)
            
            // Generate bezier curve vertices
            let curveVertices = generateBezierCurve(from: fromPos, to: toPos, segments: 32)
            let color = SIMD4<Float>(0.494, 0.827, 0.129, 1.0) // Green
            
            for (i, pos) in curveVertices.enumerated() {
                let progress = Float(i) / Float(curveVertices.count - 1)
                vertices.append(ConnectionVertex(
                    position: SIMD2<Float>(Float(pos.x), Float(pos.y)),
                    color: color,
                    progress: progress,
                    thickness: 2.5
                ))
            }
        }
        
        guard !vertices.isEmpty else { return }
        
        memcpy(connectionVertexBuffer.contents(), &vertices, MemoryLayout<ConnectionVertex>.stride * vertices.count)
        
        encoder.setRenderPipelineState(connectionPipelineState)
        encoder.setVertexBuffer(connectionVertexBuffer, offset: 0, index: Int(BufferIndexVertices.rawValue))
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func renderConnectionPreview(encoder: MTLRenderCommandEncoder, preview: ConnectionPreview) {
        let curveVertices = generateBezierCurve(from: preview.fromPosition, to: preview.toPosition, segments: 32)
        let color = preview.isValid ?
            SIMD4<Float>(0.494, 0.827, 0.129, 0.9) : // Green
            SIMD4<Float>(0.937, 0.267, 0.267, 0.9)   // Red
        
        var vertices: [ConnectionVertex] = []
        for (i, pos) in curveVertices.enumerated() {
            let progress = Float(i) / Float(curveVertices.count - 1)
            vertices.append(ConnectionVertex(
                position: SIMD2<Float>(Float(pos.x), Float(pos.y)),
                color: color,
                progress: progress,
                thickness: 3.0
            ))
        }
        
        memcpy(connectionVertexBuffer.contents(), &vertices, MemoryLayout<ConnectionVertex>.stride * vertices.count)
        
        encoder.setRenderPipelineState(connectionPreviewPipelineState)
        encoder.setVertexBuffer(connectionVertexBuffer, offset: 0, index: Int(BufferIndexVertices.rawValue))
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func renderPorts(
        encoder: MTLRenderCommandEncoder,
        nodes: [DialogueNode],
        connections: [Connection],
        hoveredNodeId: UUID?
    ) {
        // Build connected ports set
        var connectedPorts = Set<String>()
        for conn in connections {
            connectedPorts.insert("\(conn.fromNodeId)-out-\(conn.fromPortIndex)")
            connectedPorts.insert("\(conn.toNodeId)-in-\(conn.toPortIndex)")
        }
        
        var portData: [PortData] = []
        
        for node in nodes {
            let isNodeHovered = node.id == hoveredNodeId
            
            // Input ports
            for (i, _) in node.inputPorts.enumerated() {
                let pos = node.getPortPosition(type: .input, index: i)
                let isConnected = connectedPorts.contains("\(node.id)-in-\(i)")
                
                portData.append(PortData(
                    position: SIMD2<Float>(Float(pos.x), Float(pos.y)),
                    color: isConnected ?
                        SIMD4<Float>(0.494, 0.827, 0.129, 1.0) :
                        SIMD4<Float>(0.420, 0.447, 0.502, 1.0),
                    radius: isNodeHovered ? 8 : 7,
                    isConnected: isConnected ? 1 : 0,
                    isHovered: isNodeHovered ? 1 : 0,
                    glowIntensity: isConnected ? 0.5 : 0
                ))
            }
            
            // Output ports
            for (i, _) in node.outputPorts.enumerated() {
                let pos = node.getPortPosition(type: .output, index: i)
                let isConnected = connectedPorts.contains("\(node.id)-out-\(i)")
                
                portData.append(PortData(
                    position: SIMD2<Float>(Float(pos.x), Float(pos.y)),
                    color: isConnected ?
                        SIMD4<Float>(0.494, 0.827, 0.129, 1.0) :
                        SIMD4<Float>(0.420, 0.447, 0.502, 1.0),
                    radius: isNodeHovered ? 8 : 7,
                    isConnected: isConnected ? 1 : 0,
                    isHovered: isNodeHovered ? 1 : 0,
                    glowIntensity: isConnected ? 0.5 : 0
                ))
            }
        }
        
        guard !portData.isEmpty else { return }
        
        memcpy(portInstanceBuffer.contents(), &portData, MemoryLayout<PortData>.stride * portData.count)
        
        encoder.setRenderPipelineState(portPipelineState)
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(portInstanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: portData.count)
    }
    
    private func renderSelectionBox(encoder: MTLRenderCommandEncoder, start: CGPoint, end: CGPoint) {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        
        var rect = SIMD4<Float>(Float(minX), Float(minY), Float(width), Float(height))
        let rectBuffer = device.makeBuffer(bytes: &rect, length: MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)
        
        encoder.setRenderPipelineState(selectionBoxPipelineState)
        encoder.setVertexBuffer(rectBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: Int(BufferIndexUniforms.rawValue))
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    // MARK: - Helpers
    
    private func generateBezierCurve(from: CGPoint, to: CGPoint, segments: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        
        let dx = to.x - from.x
        let controlOffset = abs(dx) * 0.5
        
        let cp1 = CGPoint(x: from.x + controlOffset, y: from.y)
        let cp2 = CGPoint(x: to.x - controlOffset, y: to.y)
        
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = cubicBezier(t: t, p0: from, p1: cp1, p2: cp2, p3: to)
            points.append(point)
        }
        
        return points
    }
    
    private func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        
        return CGPoint(
            x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
            y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y
        )
    }
    
    private func colorToSIMD4(_ color: Color) -> SIMD4<Float> {
        // Convert SwiftUI Color to SIMD4 using NSColor
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.blue
        return SIMD4<Float>(
            Float(nsColor.redComponent),
            Float(nsColor.greenComponent),
            Float(nsColor.blueComponent),
            Float(nsColor.alphaComponent)
        )
    }
    
    private func createViewProjectionMatrix(width: Float, height: Float, zoom: Float, panX: Float, panY: Float) -> matrix_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = zoom * 2.0 / width
        matrix.columns.1.y = -zoom * 2.0 / height
        matrix.columns.3.x = (panX * 2.0 / width) - 1.0
        matrix.columns.3.y = -(panY * 2.0 / height) + 1.0
        return matrix
    }
    private func matrix4x4_translation(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(x, y, z, 1)
        return matrix
    }
}

// MARK: - Shader Type Definitions (Mirror of ShaderTypes.h)

struct NodeVertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
    var color: SIMD4<Float>
}

struct NodeInstanceData {
    var transform: matrix_float4x4
    var backgroundColor: SIMD4<Float>
    var headerColor: SIMD4<Float>
    var borderColor: SIMD4<Float>
    var size: SIMD2<Float>
    var cornerRadius: Float
    var borderWidth: Float
    var glowIntensity: Float
    var isSelected: Float
    var isHovered: Float
    var padding: Float
}

struct ConnectionVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
    var progress: Float
    var thickness: Float
}

struct Uniforms {
    var viewProjectionMatrix: matrix_float4x4
    var viewportSize: SIMD2<Float>
    var time: Float
    var zoom: Float
    var pan: SIMD2<Float>
    var padding1: Float
    var padding2: Float
}

struct GridUniforms {
    var minorGridColor: SIMD4<Float>
    var majorGridColor: SIMD4<Float>
    var backgroundColor: SIMD4<Float>
    var minorGridSize: Float
    var majorGridSize: Float
    var zoom: Float
    var padding: Float
}

struct PortData {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
    var radius: Float
    var isConnected: Float
    var isHovered: Float
    var glowIntensity: Float
}

struct BloomParams {
    var threshold: Float
    var intensity: Float
    var radius: Float
    var iterations: Int32
}

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var maxLife: Float
    var padding: Float
}
