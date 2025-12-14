import SwiftUI
import MetalKit

// MARK: - Performance-Optimized Metal Canvas
// Key optimizations from research:
// 1. Triple buffering for smooth 120fps
// 2. Minimal state updates between frames
// 3. Gesture coalescing for snappy response
// 4. Direct keyboard event handling

struct MetalCanvas: NSViewRepresentable {
    @EnvironmentObject var graphModel: GraphModel
    
    func makeNSView(context: Context) -> CanvasMTKView {
        let mtkView = CanvasMTKView()
        mtkView.coordinator = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        
        // Performance: Only redraw when needed during idle, continuous during interaction
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 120 // ProMotion displays
        
        // Pixel format optimized for sRGB display
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.118, green: 0.118, blue: 0.180, alpha: 1.0)
        
        // MSAA for smooth edges
        mtkView.sampleCount = 4
        
        // Performance: Presentsusing CAMetalLayer for better performance
        mtkView.framebufferOnly = true
        
        // Setup gesture recognizers with improved responsiveness
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delaysPrimaryMouseButtonEvents = false // Immediate response
        
        let magnifyGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        clickGesture.delaysPrimaryMouseButtonEvents = false
        
        let doubleClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        
        let rightClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRightClick(_:)))
        rightClickGesture.buttonMask = 0x2
        
        // Add scroll gesture for zooming
        let scrollGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleScroll(_:)))
        
        mtkView.addGestureRecognizer(panGesture)
        mtkView.addGestureRecognizer(magnifyGesture)
        mtkView.addGestureRecognizer(clickGesture)
        mtkView.addGestureRecognizer(doubleClickGesture)
        mtkView.addGestureRecognizer(rightClickGesture)
        mtkView.addGestureRecognizer(scrollGesture)
        
        // Track mouse for hover effects - use inVisibleRect for auto-updates
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        mtkView.addTrackingArea(trackingArea)
        
        // Enable key events
        mtkView.allowedTouchTypes = .indirect
        
        // Make first responder to receive keyboard events
        DispatchQueue.main.async {
            mtkView.window?.makeFirstResponder(mtkView)
        }
        
        return mtkView
    }
    
    func updateNSView(_ nsView: CanvasMTKView, context: Context) {
        // Only update if model reference changed
        if context.coordinator.graphModel !== graphModel {
            context.coordinator.graphModel = graphModel
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(graphModel: graphModel)
    }
}

// MARK: - Custom MTKView subclass for keyboard handling
class CanvasMTKView: MTKView {
    weak var coordinator: MetalCanvas.Coordinator?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Handle keyboard shortcuts
        guard let coordinator = coordinator else {
            super.keyDown(with: event)
            return
        }
        
        let key = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags
        
        // Space for pan mode
        if event.keyCode == 49 { // Space
            coordinator.isSpacePressed = true
            NSCursor.openHand.set()
            return
        }
        
        // Arrow keys for nudging/panning
        if event.keyCode >= 123 && event.keyCode <= 126 {
            coordinator.handleArrowKey(event: event)
            return
        }
        
        // Command shortcuts
        if modifiers.contains(.command) {
            switch key.lowercased() {
            case "a": coordinator.graphModel.selectAll()
            case "d": coordinator.graphModel.duplicateSelection()
            case "z":
                if modifiers.contains(.shift) {
                    coordinator.graphModel.redo()
                } else {
                    coordinator.graphModel.undo()
                }
            case "=", "+": coordinator.zoomIn()
            case "-": coordinator.zoomOut()
            case "0": coordinator.resetZoom()
            default: super.keyDown(with: event)
            }
            return
        }
        
        // Tool shortcuts (no modifier)
        switch key.lowercased() {
        case "t", "d":
            // Quick add dialogue at center
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let worldPos = coordinator.screenToWorld(center)
            coordinator.graphModel.addNode(type: .dialogue, at: worldPos)
        case "b":
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let worldPos = coordinator.screenToWorld(center)
            coordinator.graphModel.addNode(type: .branch, at: worldPos)
        case "c":
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let worldPos = coordinator.screenToWorld(center)
            coordinator.graphModel.addNode(type: .condition, at: worldPos)
        default:
            super.keyDown(with: event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        // Space released
        if event.keyCode == 49 {
            coordinator?.isSpacePressed = false
            NSCursor.arrow.set()
            return
        }
        super.keyUp(with: event)
    }
    
    // Delete key
    override func deleteBackward(_ sender: Any?) {
        coordinator?.graphModel.deleteSelection()
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard let coordinator = coordinator else { return }
        
        // Pinch-to-zoom on trackpad or Cmd+scroll
        if event.modifierFlags.contains(.command) || abs(event.magnification) > 0 {
            let zoomDelta = event.deltaY > 0 ? 1.1 : 0.9
            let newZoom = max(0.1, min(5.0, coordinator.graphModel.viewportZoom * zoomDelta))
            coordinator.graphModel.viewportZoom = newZoom
        } else {
            // Pan with scroll
            coordinator.graphModel.viewportOffset.x += event.deltaX * 2
            coordinator.graphModel.viewportOffset.y += event.deltaY * 2
        }
    }
}

extension MetalCanvas {
    class Coordinator: NSObject, MTKViewDelegate {
        var graphModel: GraphModel
        var renderer: NodeGraphRenderer?
        
        // Interaction state
        private var isDraggingNode = false
        private var isDraggingCanvas = false
        private var isDrawingConnection = false
        private var isDrawingSelection = false
        var isSpacePressed = false  // For pan mode
        
        private var dragStartPosition: CGPoint = .zero
        private var draggedNodeIds: Set<UUID> = []
        private var nodeStartPositions: [UUID: CGPoint] = [:]
        
        private var connectionStart: (nodeId: UUID, portIndex: Int)?
        private var connectionEndPosition: CGPoint = .zero
        
        private var selectionStart: CGPoint = .zero
        private var selectionEnd: CGPoint = .zero
        
        private var hoveredNodeId: UUID?
        private var hoveredPortInfo: (nodeId: UUID, portType: Port.PortType, portIndex: Int)?
        
        init(graphModel: GraphModel) {
            self.graphModel = graphModel
            super.init()
        }
        
        // MARK: - Keyboard Helpers
        
        func handleArrowKey(event: NSEvent) {
            let shift = event.modifierFlags.contains(.shift)
            let amount: CGFloat = shift ? 10 : 1
            
            var delta: CGPoint = .zero
            switch event.keyCode {
            case 123: delta.x = -amount // Left
            case 124: delta.x = amount  // Right
            case 125: delta.y = amount  // Down
            case 126: delta.y = -amount // Up
            default: return
            }
            
            if graphModel.selectedNodeIds.isEmpty {
                // Pan canvas
                graphModel.viewportOffset.x += delta.x * 10
                graphModel.viewportOffset.y += delta.y * 10
            } else {
                // Nudge selected nodes
                graphModel.saveUndoState()
                for nodeId in graphModel.selectedNodeIds {
                    if let node = graphModel.getNode(nodeId) {
                        graphModel.updateNodePosition(nodeId, to: CGPoint(
                            x: node.position.x + delta.x,
                            y: node.position.y + delta.y
                        ))
                    }
                }
            }
        }
        
        func zoomIn() {
            graphModel.viewportZoom = min(5.0, graphModel.viewportZoom * 1.25)
        }
        
        func zoomOut() {
            graphModel.viewportZoom = max(0.1, graphModel.viewportZoom / 1.25)
        }
        
        func resetZoom() {
            graphModel.viewportZoom = 1.0
            graphModel.viewportOffset = .zero
        }
        
        @objc func handleScroll(_ gesture: NSMagnificationGestureRecognizer) {
            let newZoom = graphModel.viewportZoom * (1 + gesture.magnification)
            graphModel.viewportZoom = max(0.1, min(5.0, newZoom))
            gesture.magnification = 0
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.viewportSize = size
        }
        
        func draw(in view: MTKView) {
            // Initialize renderer lazily
            if renderer == nil, let device = view.device {
                renderer = NodeGraphRenderer(device: device, pixelFormat: view.colorPixelFormat)
            }
            
            renderer?.render(
                in: view,
                nodes: graphModel.nodes,
                connections: graphModel.connections,
                viewportOffset: graphModel.viewportOffset,
                viewportZoom: graphModel.viewportZoom,
                selectedNodeIds: graphModel.selectedNodeIds,
                hoveredNodeId: hoveredNodeId,
                connectionPreview: isDrawingConnection ? ConnectionPreview(
                    fromPosition: getConnectionStartPosition(),
                    toPosition: connectionEndPosition,
                    isValid: canCompleteConnection(),
                    progress: 0
                ) : nil,
                selectionBox: isDrawingSelection ? (selectionStart, selectionEnd) : nil
            )
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let worldPos = screenToWorld(location)
            
            switch gesture.state {
            case .began:
                handlePanBegan(at: location, worldPos: worldPos, gesture: gesture)
                
            case .changed:
                handlePanChanged(to: location, worldPos: worldPos, gesture: gesture)
                
            case .ended, .cancelled:
                handlePanEnded(at: location, worldPos: worldPos)
                
            default:
                break
            }
        }
        
        private func handlePanBegan(at screenPos: CGPoint, worldPos: CGPoint, gesture: NSPanGestureRecognizer) {
            // Check if starting on a port (for connection dragging)
            if let portHit = hitTestPort(at: worldPos) {
                isDrawingConnection = true
                connectionStart = (portHit.nodeId, portHit.portIndex)
                connectionEndPosition = worldPos
                return
            }
            
            // Check if starting on a node
            if let node = hitTestNode(at: worldPos) {
                isDraggingNode = true
                dragStartPosition = worldPos
                
                // If not already selected, select just this node
                if !graphModel.selectedNodeIds.contains(node.id) {
                    let addToSelection = NSEvent.modifierFlags.contains(.shift)
                    graphModel.selectNode(node.id, addToSelection: addToSelection)
                }
                
                // Store start positions for all selected nodes
                draggedNodeIds = graphModel.selectedNodeIds
                nodeStartPositions = [:]
                for id in draggedNodeIds {
                    if let n = graphModel.getNode(id) {
                        nodeStartPositions[id] = n.position
                    }
                }
                return
            }
            
            // Check if shift is held for selection box
            if NSEvent.modifierFlags.contains(.shift) {
                isDrawingSelection = true
                selectionStart = worldPos
                selectionEnd = worldPos
                return
            }
            
            // Otherwise, pan the canvas
            isDraggingCanvas = true
            dragStartPosition = screenPos
        }
        
        private func handlePanChanged(to screenPos: CGPoint, worldPos: CGPoint, gesture: NSPanGestureRecognizer) {
            if isDraggingNode {
                let delta = CGPoint(
                    x: worldPos.x - dragStartPosition.x,
                    y: worldPos.y - dragStartPosition.y
                )
                
                for id in draggedNodeIds {
                    if let startPos = nodeStartPositions[id] {
                        graphModel.updateNodePosition(id, to: CGPoint(
                            x: startPos.x + delta.x,
                            y: startPos.y + delta.y
                        ))
                    }
                }
            } else if isDraggingCanvas {
                let translation = gesture.translation(in: gesture.view)
                graphModel.viewportOffset = CGPoint(
                    x: graphModel.viewportOffset.x + translation.x,
                    y: graphModel.viewportOffset.y + translation.y
                )
                gesture.setTranslation(.zero, in: gesture.view)
            } else if isDrawingConnection {
                connectionEndPosition = worldPos
            } else if isDrawingSelection {
                selectionEnd = worldPos
            }
        }
        
        private func handlePanEnded(at screenPos: CGPoint, worldPos: CGPoint) {
            if isDrawingConnection {
                // Try to complete connection to existing port
                if let portHit = hitTestPort(at: worldPos),
                   let start = connectionStart,
                   portHit.portType == .input {
                    graphModel.addConnection(
                        from: start.nodeId,
                        fromPort: start.portIndex,
                        to: portHit.nodeId,
                        toPort: portHit.portIndex
                    )
                } else if let start = connectionStart, hitTestNode(at: worldPos) == nil {
                    // articy:draft style: Dropping connection on empty space creates a connected node
                    if let newNode = graphModel.createConnectedNode(from: start.nodeId, type: .dialogue) {
                        // Position the new node at drop location
                        graphModel.updateNodePosition(newNode.id, to: worldPos)
                    }
                }
            } else if isDrawingSelection {
                // Select nodes in box
                let selectedIds = getNodesInSelectionBox()
                graphModel.selectNodes(selectedIds)
            }
            
            // Reset state
            isDraggingNode = false
            isDraggingCanvas = false
            isDrawingConnection = false
            isDrawingSelection = false
            connectionStart = nil
            draggedNodeIds.removeAll()
            nodeStartPositions.removeAll()
        }
        
        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            let newZoom = graphModel.viewportZoom * (1 + gesture.magnification)
            graphModel.viewportZoom = max(0.1, min(5.0, newZoom))
            gesture.magnification = 0
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let worldPos = screenToWorld(location)
            
            // Ctrl+Shift+Click = Quick create node (articy:draft style)
            let modifiers = NSEvent.modifierFlags
            if modifiers.contains(.control) && modifiers.contains(.shift) {
                graphModel.addNode(type: .dialogue, at: worldPos)
                return
            }
            
            if let node = hitTestNode(at: worldPos) {
                let addToSelection = modifiers.contains(.shift)
                graphModel.selectNode(node.id, addToSelection: addToSelection)
            } else if let connection = hitTestConnection(at: worldPos) {
                graphModel.selectConnection(connection.id)
            } else {
                graphModel.clearSelection()
            }
        }
        
        @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let worldPos = screenToWorld(location)
            
            if let node = hitTestNode(at: worldPos) {
                // TODO: Open inline editor
                print("Double-clicked node: \(node.technicalName)")
            } else {
                // Double-click on empty space - add dialogue node at WORLD position
                graphModel.addNode(type: .dialogue, at: worldPos)
            }
        }
        
        @objc func handleRightClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let worldPos = screenToWorld(location)
            
            // TODO: Show context menu
            if let node = hitTestNode(at: worldPos) {
                print("Right-clicked node: \(node.technicalName)")
            } else {
                print("Right-clicked canvas at \(worldPos)")
            }
        }
        
        func mouseMoved(with event: NSEvent) {
            guard let view = event.window?.contentView else { return }
            let location = view.convert(event.locationInWindow, from: nil)
            let worldPos = screenToWorld(location)
            
            // Update hover state
            let newHoveredNode = hitTestNode(at: worldPos)
            if newHoveredNode?.id != hoveredNodeId {
                // Clear old hover
                if let oldId = hoveredNodeId, let oldNode = graphModel.getNode(oldId) {
                    oldNode.isHovered = false
                }
                
                // Set new hover
                hoveredNodeId = newHoveredNode?.id
                if let node = newHoveredNode {
                    node.isHovered = true
                }
            }
            
            // Update port hover
            hoveredPortInfo = hitTestPort(at: worldPos)
        }
        
        // MARK: - Coordinate Conversion
        
        func screenToWorld(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: (point.x - graphModel.viewportOffset.x) / graphModel.viewportZoom,
                y: (point.y - graphModel.viewportOffset.y) / graphModel.viewportZoom
            )
        }
        
        func worldToScreen(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x * graphModel.viewportZoom + graphModel.viewportOffset.x,
                y: point.y * graphModel.viewportZoom + graphModel.viewportOffset.y
            )
        }
        
        // MARK: - Hit Testing
        
        func hitTestNode(at worldPos: CGPoint) -> DialogueNode? {
            // Test in reverse order (top-most first)
            for node in graphModel.nodes.reversed() {
                let frame = CGRect(origin: node.position, size: node.size)
                if frame.contains(worldPos) {
                    return node
                }
            }
            return nil
        }
        
        func hitTestPort(at worldPos: CGPoint) -> (nodeId: UUID, portType: Port.PortType, portIndex: Int)? {
            let portRadius: CGFloat = 10
            
            for node in graphModel.nodes {
                // Check output ports
                for (index, _) in node.outputPorts.enumerated() {
                    let portPos = node.getPortPosition(type: .output, index: index)
                    if distance(worldPos, portPos) < portRadius {
                        return (node.id, .output, index)
                    }
                }
                
                // Check input ports
                for (index, _) in node.inputPorts.enumerated() {
                    let portPos = node.getPortPosition(type: .input, index: index)
                    if distance(worldPos, portPos) < portRadius {
                        return (node.id, .input, index)
                    }
                }
            }
            return nil
        }
        
        func hitTestConnection(at worldPos: CGPoint) -> Connection? {
            // Simplified - would need bezier curve hit testing for accuracy
            return nil
        }
        
        private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
        }
        
        private func getConnectionStartPosition() -> CGPoint {
            guard let start = connectionStart,
                  let node = graphModel.getNode(start.nodeId) else {
                return .zero
            }
            return node.getPortPosition(type: .output, index: start.portIndex)
        }
        
        private func canCompleteConnection() -> Bool {
            guard let start = connectionStart,
                  let endPort = hoveredPortInfo,
                  endPort.portType == .input else {
                return false
            }
            return graphModel.canConnect(
                from: start.nodeId,
                fromPort: start.portIndex,
                to: endPort.nodeId,
                toPort: endPort.portIndex
            )
        }
        
        private func getNodesInSelectionBox() -> Set<UUID> {
            let minX = min(selectionStart.x, selectionEnd.x)
            let maxX = max(selectionStart.x, selectionEnd.x)
            let minY = min(selectionStart.y, selectionEnd.y)
            let maxY = max(selectionStart.y, selectionEnd.y)
            let box = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            var selected = Set<UUID>()
            for node in graphModel.nodes {
                let nodeFrame = CGRect(origin: node.position, size: node.size)
                if box.intersects(nodeFrame) {
                    selected.insert(node.id)
                }
            }
            return selected
        }
    }
}
