import SwiftUI
import Carbon.HIToolbox

// MARK: - Figma-Inspired Interaction Manager
// Key insights from Figma:
// 1. Keyboard-first: Everything achievable without mouse
// 2. Modifier keys change behavior smoothly
// 3. Visual feedback for every action
// 4. Spring animations for organic feel
// 5. Cursor changes communicate affordances

final class InteractionManager: ObservableObject {
    // MARK: - Input State
    @Published var modifiers: NSEvent.ModifierFlags = []
    @Published var mousePosition: CGPoint = .zero
    @Published var isSpacePressed: Bool = false
    @Published var cursorMode: CursorMode = .select
    
    // MARK: - Interaction State
    @Published var dragState: DragState = .idle
    @Published var hoverState: HoverState = .none
    @Published var focusedNodeId: UUID?
    @Published var keyboardCursor: CGPoint = .zero // Figma-style keyboard navigation
    @Published var showKeyboardCursor: Bool = false
    
    // MARK: - Animation State
    @Published var connectionPreviewProgress: CGFloat = 0
    @Published var selectionPulse: CGFloat = 0
    
    weak var graphModel: GraphModel?
    private var keyRepeatTimer: Timer?
    private var animationDisplayLink: CVDisplayLink?
    
    // MARK: - Cursor Modes (Figma-style)
    enum CursorMode: Equatable {
        case select           // Default arrow
        case hand             // Panning (space held or middle-click)
        case crosshair        // Placing new element
        case move             // Dragging nodes
        case connect          // Drawing connection
        case resize(Edge)     // Resizing node
        case text             // Text editing
        case forbidden        // Invalid drop target
        
        enum Edge { case n, s, e, w, ne, nw, se, sw }
        
        var nsCursor: NSCursor {
            switch self {
            case .select: return .arrow
            case .hand: return .openHand
            case .crosshair: return .crosshair
            case .move: return .closedHand
            case .connect: return .crosshair
            case .resize(let edge):
                switch edge {
                case .n, .s: return .resizeUpDown
                case .e, .w: return .resizeLeftRight
                case .ne, .sw: return .crosshair // Would use custom diagonal cursor
                case .nw, .se: return .crosshair
                }
            case .text: return .iBeam
            case .forbidden: return .operationNotAllowed
            }
        }
    }
    
    // MARK: - Drag States
    enum DragState: Equatable {
        case idle
        case pending(origin: CGPoint)          // Mouse down, waiting to see if drag
        case draggingNodes(nodeIds: Set<UUID>, startPositions: [UUID: CGPoint], origin: CGPoint)
        case draggingCanvas(origin: CGPoint, startOffset: CGPoint)
        case drawingConnection(fromNode: UUID, fromPort: Int, currentEnd: CGPoint)
        case drawingSelection(origin: CGPoint, current: CGPoint)
        case resizing(nodeId: UUID, edge: CursorMode.Edge, origin: CGPoint, originalFrame: CGRect)
        
        static func == (lhs: DragState, rhs: DragState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.pending(let a), .pending(let b)): return a == b
            case (.draggingCanvas, .draggingCanvas): return true
            case (.drawingConnection, .drawingConnection): return true
            case (.drawingSelection, .drawingSelection): return true
            default: return false
            }
        }
    }
    
    // MARK: - Hover States
    enum HoverState: Equatable {
        case none
        case node(UUID)
        case nodeHeader(UUID)
        case port(nodeId: UUID, portType: Port.PortType, index: Int)
        case connection(UUID)
        case resizeHandle(nodeId: UUID, edge: CursorMode.Edge)
    }
    
    // MARK: - Keyboard Shortcuts (Figma-inspired)
    struct Shortcuts {
        // Navigation
        static let pan = Set<KeyEquivalent>([.space]) // Hold space + drag
        static let zoomIn = KeyEquivalent("+")
        static let zoomOut = KeyEquivalent("-")
        static let zoomFit = KeyEquivalent("1")
        static let zoomSelection = KeyEquivalent("2")
        static let zoom100 = KeyEquivalent("0")
        
        // Selection
        static let selectAll = KeyEquivalent("a") // Cmd+A
        static let deselectAll = KeyEquivalent.escape
        static let delete = KeyEquivalent.delete
        static let duplicate = KeyEquivalent("d") // Cmd+D
        
        // Tools
        static let selectTool = KeyEquivalent("v")
        static let handTool = KeyEquivalent("h")
        static let dialogueTool = KeyEquivalent("t")
        static let connectionTool = KeyEquivalent("c")
        
        // Editing
        static let undo = KeyEquivalent("z")
        static let redo = KeyEquivalent("z") // Cmd+Shift+Z
        static let copy = KeyEquivalent("c")
        static let paste = KeyEquivalent("v")
        static let cut = KeyEquivalent("x")
        
        // Movement (Figma-style arrow navigation)
        static let nudgeAmount: CGFloat = 1
        static let bigNudgeAmount: CGFloat = 10
        static let panAmount: CGFloat = 50
        static let bigPanAmount: CGFloat = 200
    }
    
    // MARK: - Initialization
    init() {
        setupAnimationTimer()
    }
    
    private func setupAnimationTimer() {
        // Update animations at 60fps
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.updateAnimations()
        }
    }
    
    private func updateAnimations() {
        // Animate connection preview progress
        if case .drawingConnection = dragState {
            withAnimation(.linear(duration: 0.5)) {
                connectionPreviewProgress = (connectionPreviewProgress + 0.02).truncatingRemainder(dividingBy: 1.0)
            }
        }
        
        // Pulse selected nodes subtly
        selectionPulse = (sin(Date().timeIntervalSinceReferenceDate * 2) + 1) / 2 * 0.1
    }
    
    // MARK: - Keyboard Event Handling
    func handleKeyDown(event: NSEvent) -> Bool {
        guard let graphModel = graphModel else { return false }
        
        let key = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags
        
        // Space for hand tool
        if event.keyCode == 49 && !isSpacePressed { // Space key
            isSpacePressed = true
            cursorMode = .hand
            return true
        }
        
        // Arrow keys - Figma style navigation
        if handleArrowKeys(event: event) {
            return true
        }
        
        // Command shortcuts
        if modifiers.contains(.command) {
            switch key.lowercased() {
            case "a":
                graphModel.selectAll()
                return true
            case "d":
                duplicateSelection()
                return true
            case "z":
                if modifiers.contains(.shift) {
                    graphModel.redo()
                } else {
                    graphModel.undo()
                }
                return true
            case "c":
                copySelection()
                return true
            case "v":
                pasteAtCursor()
                return true
            case "x":
                cutSelection()
                return true
            case "=", "+":
                zoomIn()
                return true
            case "-":
                zoomOut()
                return true
            case "0":
                resetZoom()
                return true
            case "1":
                zoomToFit()
                return true
            case "2":
                zoomToSelection()
                return true
            default:
                break
            }
        }
        
        // Tool shortcuts (no modifier)
        if !modifiers.contains(.command) && !modifiers.contains(.option) {
            switch key.lowercased() {
            case "v":
                cursorMode = .select
                return true
            case "h":
                cursorMode = .hand
                return true
            case "t", "d":
                // Quick add dialogue node at cursor/keyboard cursor
                let position = showKeyboardCursor ? keyboardCursor : mousePosition
                graphModel.addNode(type: .dialogue, at: position)
                return true
            case "b":
                let position = showKeyboardCursor ? keyboardCursor : mousePosition
                graphModel.addNode(type: .branch, at: position)
                return true
            case "c":
                if !graphModel.selectedNodeIds.isEmpty {
                    cursorMode = .connect
                }
                return true
            default:
                break
            }
        }
        
        // Delete/Backspace
        if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
            graphModel.deleteSelection()
            return true
        }
        
        // Escape
        if event.keyCode == 53 {
            graphModel.clearSelection()
            dragState = .idle
            cursorMode = .select
            showKeyboardCursor = false
            return true
        }
        
        // Enter - select item at keyboard cursor or edit selected node
        if event.keyCode == 36 {
            if showKeyboardCursor {
                selectAtKeyboardCursor()
            } else if graphModel.selectedNodeIds.count == 1 {
                // TODO: Enter edit mode for node
            }
            return true
        }
        
        // Tab - cycle through nodes
        if event.keyCode == 48 {
            cycleNodeSelection(reverse: modifiers.contains(.shift))
            return true
        }
        
        return false
    }
    
    func handleKeyUp(event: NSEvent) -> Bool {
        // Space released - return to select mode
        if event.keyCode == 49 { // Space
            isSpacePressed = false
            if case .draggingCanvas = dragState {
                // Keep hand cursor during drag
            } else {
                cursorMode = .select
            }
            return true
        }
        return false
    }
    
    // MARK: - Arrow Key Navigation (Figma-style)
    private func handleArrowKeys(event: NSEvent) -> Bool {
        guard let graphModel = graphModel else { return false }
        
        let modifiers = event.modifierFlags
        let hasSelection = !graphModel.selectedNodeIds.isEmpty
        
        // Determine movement amount
        let baseAmount: CGFloat = modifiers.contains(.shift) ? Shortcuts.bigNudgeAmount : Shortcuts.nudgeAmount
        
        var delta: CGPoint = .zero
        switch event.keyCode {
        case 123: delta.x = -baseAmount // Left
        case 124: delta.x = baseAmount  // Right
        case 125: delta.y = baseAmount  // Down (positive Y is down in screen coords)
        case 126: delta.y = -baseAmount // Up
        default: return false
        }
        
        if hasSelection && !modifiers.contains(.option) {
            // Move selected nodes
            graphModel.saveUndoState()
            for nodeId in graphModel.selectedNodeIds {
                if let node = graphModel.getNode(nodeId) {
                    let newPos = CGPoint(x: node.position.x + delta.x, y: node.position.y + delta.y)
                    graphModel.updateNodePosition(nodeId, to: newPos)
                }
            }
        } else {
            // Pan canvas (Figma style - no selection means arrow keys pan)
            let panDelta = modifiers.contains(.shift) ? 
                CGPoint(x: delta.x * 20, y: delta.y * 20) :
                CGPoint(x: delta.x * 5, y: delta.y * 5)
            graphModel.viewportOffset.x += panDelta.x
            graphModel.viewportOffset.y += panDelta.y
            
            // Move keyboard cursor if visible
            if showKeyboardCursor {
                keyboardCursor.x += delta.x * 10
                keyboardCursor.y += delta.y * 10
            }
        }
        
        return true
    }
    
    // MARK: - Mouse Event Handling
    func handleMouseDown(at screenPos: CGPoint, worldPos: CGPoint, button: Int, clickCount: Int) {
        guard let graphModel = graphModel else { return }
        
        // Double-click handling
        if clickCount == 2 && button == 0 {
            handleDoubleClick(at: worldPos)
            return
        }
        
        // Right-click context menu
        if button == 1 {
            handleRightClick(at: worldPos)
            return
        }
        
        // Space held = pan mode
        if isSpacePressed {
            dragState = .draggingCanvas(origin: screenPos, startOffset: graphModel.viewportOffset)
            cursorMode = .hand
            return
        }
        
        // Check what we're clicking on
        switch hoverState {
        case .port(let nodeId, let portType, let index):
            if portType == .output {
                // Start drawing connection
                dragState = .drawingConnection(fromNode: nodeId, fromPort: index, currentEnd: worldPos)
                cursorMode = .connect
            }
            
        case .resizeHandle(let nodeId, let edge):
            if let node = graphModel.getNode(nodeId) {
                let frame = CGRect(origin: node.position, size: node.size)
                dragState = .resizing(nodeId: nodeId, edge: edge, origin: worldPos, originalFrame: frame)
                cursorMode = .resize(edge)
            }
            
        case .node(let nodeId), .nodeHeader(let nodeId):
            // Select and prepare to drag
            let addToSelection = modifiers.contains(.shift)
            if !graphModel.selectedNodeIds.contains(nodeId) {
                graphModel.selectNode(nodeId, addToSelection: addToSelection)
            }
            
            // Prepare node drag
            var startPositions: [UUID: CGPoint] = [:]
            for id in graphModel.selectedNodeIds {
                if let node = graphModel.getNode(id) {
                    startPositions[id] = node.position
                }
            }
            dragState = .draggingNodes(
                nodeIds: graphModel.selectedNodeIds,
                startPositions: startPositions,
                origin: worldPos
            )
            cursorMode = .move
            
        case .connection(let connectionId):
            graphModel.selectConnection(connectionId)
            
        case .none:
            if modifiers.contains(.shift) {
                // Start selection box
                dragState = .drawingSelection(origin: worldPos, current: worldPos)
            } else {
                // Click on empty space - deselect and prepare for canvas drag
                graphModel.clearSelection()
                dragState = .pending(origin: screenPos)
            }
        }
    }
    
    func handleMouseDragged(to screenPos: CGPoint, worldPos: CGPoint) {
        guard let graphModel = graphModel else { return }
        
        switch dragState {
        case .pending(let origin):
            // Check if we've moved enough to start dragging
            let distance = hypot(screenPos.x - origin.x, screenPos.y - origin.y)
            if distance > 3 {
                // Start canvas pan
                dragState = .draggingCanvas(origin: origin, startOffset: graphModel.viewportOffset)
                cursorMode = .hand
            }
            
        case .draggingCanvas(let origin, let startOffset):
            let delta = CGPoint(x: screenPos.x - origin.x, y: screenPos.y - origin.y)
            graphModel.viewportOffset = CGPoint(
                x: startOffset.x + delta.x,
                y: startOffset.y + delta.y
            )
            
        case .draggingNodes(let nodeIds, let startPositions, let origin):
            let delta = CGPoint(x: worldPos.x - origin.x, y: worldPos.y - origin.y)
            for nodeId in nodeIds {
                if let startPos = startPositions[nodeId] {
                    let newPos = CGPoint(x: startPos.x + delta.x, y: startPos.y + delta.y)
                    // Snap to grid if shift held
                    let snappedPos = modifiers.contains(.shift) ? snapToGrid(newPos) : newPos
                    graphModel.updateNodePosition(nodeId, to: snappedPos)
                }
            }
            
        case .drawingConnection(let fromNode, let fromPort, _):
            dragState = .drawingConnection(fromNode: fromNode, fromPort: fromPort, currentEnd: worldPos)
            // Update cursor based on valid drop target
            if case .port(_, .input, _) = hoverState {
                cursorMode = .connect
            } else {
                cursorMode = .forbidden
            }
            
        case .drawingSelection(let origin, _):
            dragState = .drawingSelection(origin: origin, current: worldPos)
            
        case .resizing(let nodeId, let edge, let origin, let originalFrame):
            if let node = graphModel.getNode(nodeId) {
                let delta = CGPoint(x: worldPos.x - origin.x, y: worldPos.y - origin.y)
                let newFrame = calculateResizedFrame(original: originalFrame, edge: edge, delta: delta)
                node.position = newFrame.origin
                node.size = newFrame.size
            }
            
        case .idle:
            break
        }
    }
    
    func handleMouseUp(at screenPos: CGPoint, worldPos: CGPoint) {
        guard let graphModel = graphModel else { return }
        
        switch dragState {
        case .draggingNodes(let nodeIds, let startPositions, _):
            // Save undo state for node movement
            if !nodeIds.isEmpty {
                // Check if nodes actually moved
                var moved = false
                for nodeId in nodeIds {
                    if let node = graphModel.getNode(nodeId),
                       let startPos = startPositions[nodeId] {
                        if node.position != startPos {
                            moved = true
                            break
                        }
                    }
                }
                if moved {
                    graphModel.saveUndoState()
                }
            }
            
        case .drawingConnection(let fromNode, let fromPort, _):
            // Try to complete connection
            if case .port(let toNode, .input, let toPort) = hoverState {
                graphModel.addConnection(from: fromNode, fromPort: fromPort, to: toNode, toPort: toPort)
            }
            
        case .drawingSelection(let origin, let current):
            // Select nodes in box
            let minX = min(origin.x, current.x)
            let maxX = max(origin.x, current.x)
            let minY = min(origin.y, current.y)
            let maxY = max(origin.y, current.y)
            let box = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            var selectedIds = Set<UUID>()
            for node in graphModel.nodes {
                let nodeFrame = CGRect(origin: node.position, size: node.size)
                if box.intersects(nodeFrame) {
                    selectedIds.insert(node.id)
                }
            }
            graphModel.selectNodes(selectedIds)
            
        default:
            break
        }
        
        // Reset state
        dragState = .idle
        cursorMode = isSpacePressed ? .hand : .select
    }
    
    func handleMouseMoved(to screenPos: CGPoint, worldPos: CGPoint) {
        mousePosition = worldPos
        updateHoverState(at: worldPos)
        updateCursor()
    }
    
    func handleScroll(delta: CGPoint, at screenPos: CGPoint) {
        guard let graphModel = graphModel else { return }
        
        if modifiers.contains(.command) || modifiers.contains(.option) {
            // Zoom centered on mouse position
            let zoomDelta = delta.y > 0 ? 1.1 : 0.9
            let newZoom = max(0.1, min(5.0, graphModel.viewportZoom * zoomDelta))
            
            // Zoom toward mouse position
            let mouseWorld = screenToWorld(screenPos, graphModel: graphModel)
            graphModel.viewportZoom = newZoom
            let mouseWorldAfter = screenToWorld(screenPos, graphModel: graphModel)
            let correction = CGPoint(
                x: (mouseWorldAfter.x - mouseWorld.x) * newZoom,
                y: (mouseWorldAfter.y - mouseWorld.y) * newZoom
            )
            graphModel.viewportOffset.x += correction.x
            graphModel.viewportOffset.y += correction.y
        } else {
            // Pan
            graphModel.viewportOffset.x += delta.x
            graphModel.viewportOffset.y += delta.y
        }
    }
    
    // MARK: - Hover State Management
    private func updateHoverState(at worldPos: CGPoint) {
        guard let graphModel = graphModel else { return }
        
        // Priority order: ports > resize handles > node header > node body > connections
        
        // Check ports first (higher priority)
        for node in graphModel.nodes.reversed() {
            // Output ports
            for (index, _) in node.outputPorts.enumerated() {
                let portPos = node.getPortPosition(type: .output, index: index)
                if distance(worldPos, portPos) < 12 {
                    hoverState = .port(nodeId: node.id, portType: .output, index: index)
                    return
                }
            }
            // Input ports
            for (index, _) in node.inputPorts.enumerated() {
                let portPos = node.getPortPosition(type: .input, index: index)
                if distance(worldPos, portPos) < 12 {
                    hoverState = .port(nodeId: node.id, portType: .input, index: index)
                    return
                }
            }
        }
        
        // Check resize handles
        for node in graphModel.nodes.reversed() {
            if let edge = hitTestResizeHandle(node: node, at: worldPos) {
                hoverState = .resizeHandle(nodeId: node.id, edge: edge)
                return
            }
        }
        
        // Check nodes
        for node in graphModel.nodes.reversed() {
            let frame = CGRect(origin: node.position, size: node.size)
            if frame.contains(worldPos) {
                // Check if in header area (top 32 pixels)
                let headerRect = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 32)
                if headerRect.contains(worldPos) {
                    hoverState = .nodeHeader(node.id)
                } else {
                    hoverState = .node(node.id)
                }
                return
            }
        }
        
        hoverState = .none
    }
    
    private func updateCursor() {
        guard case .idle = dragState else { return }
        
        switch hoverState {
        case .port:
            cursorMode = .connect
        case .resizeHandle(_, let edge):
            cursorMode = .resize(edge)
        case .nodeHeader:
            cursorMode = .move
        case .node:
            cursorMode = .select
        case .connection:
            cursorMode = .select
        case .none:
            cursorMode = isSpacePressed ? .hand : .select
        }
        
        cursorMode.nsCursor.set()
    }
    
    // MARK: - Helper Functions
    private func handleDoubleClick(at worldPos: CGPoint) {
        guard let graphModel = graphModel else { return }
        
        // Double-click on node = edit it
        for node in graphModel.nodes.reversed() {
            let frame = CGRect(origin: node.position, size: node.size)
            if frame.contains(worldPos) {
                // TODO: Enter edit mode
                focusedNodeId = node.id
                return
            }
        }
        
        // Double-click on empty space = add node
        graphModel.addNode(type: .dialogue, at: worldPos)
    }
    
    private func handleRightClick(at worldPos: CGPoint) {
        // TODO: Show context menu
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
    
    private func screenToWorld(_ point: CGPoint, graphModel: GraphModel) -> CGPoint {
        CGPoint(
            x: (point.x - graphModel.viewportOffset.x) / graphModel.viewportZoom,
            y: (point.y - graphModel.viewportOffset.y) / graphModel.viewportZoom
        )
    }
    
    private func snapToGrid(_ point: CGPoint, gridSize: CGFloat = 10) -> CGPoint {
        CGPoint(
            x: round(point.x / gridSize) * gridSize,
            y: round(point.y / gridSize) * gridSize
        )
    }
    
    private func hitTestResizeHandle(node: DialogueNode, at point: CGPoint) -> CursorMode.Edge? {
        let frame = CGRect(origin: node.position, size: node.size)
        let handleSize: CGFloat = 8
        
        // Corner handles
        if distance(point, CGPoint(x: frame.maxX, y: frame.maxY)) < handleSize { return .se }
        if distance(point, CGPoint(x: frame.minX, y: frame.maxY)) < handleSize { return .sw }
        if distance(point, CGPoint(x: frame.maxX, y: frame.minY)) < handleSize { return .ne }
        if distance(point, CGPoint(x: frame.minX, y: frame.minY)) < handleSize { return .nw }
        
        // Edge handles
        let edgeTolerance: CGFloat = 4
        if abs(point.x - frame.maxX) < edgeTolerance && point.y > frame.minY && point.y < frame.maxY { return .e }
        if abs(point.x - frame.minX) < edgeTolerance && point.y > frame.minY && point.y < frame.maxY { return .w }
        if abs(point.y - frame.maxY) < edgeTolerance && point.x > frame.minX && point.x < frame.maxX { return .s }
        if abs(point.y - frame.minY) < edgeTolerance && point.x > frame.minX && point.x < frame.maxX { return .n }
        
        return nil
    }
    
    private func calculateResizedFrame(original: CGRect, edge: CursorMode.Edge, delta: CGPoint) -> CGRect {
        var frame = original
        let minSize: CGFloat = 50
        
        switch edge {
        case .e:
            frame.size.width = max(minSize, original.width + delta.x)
        case .w:
            let newWidth = max(minSize, original.width - delta.x)
            frame.origin.x = original.maxX - newWidth
            frame.size.width = newWidth
        case .s:
            frame.size.height = max(minSize, original.height + delta.y)
        case .n:
            let newHeight = max(minSize, original.height - delta.y)
            frame.origin.y = original.maxY - newHeight
            frame.size.height = newHeight
        case .se:
            frame.size.width = max(minSize, original.width + delta.x)
            frame.size.height = max(minSize, original.height + delta.y)
        case .sw:
            let newWidth = max(minSize, original.width - delta.x)
            frame.origin.x = original.maxX - newWidth
            frame.size.width = newWidth
            frame.size.height = max(minSize, original.height + delta.y)
        case .ne:
            frame.size.width = max(minSize, original.width + delta.x)
            let newHeight = max(minSize, original.height - delta.y)
            frame.origin.y = original.maxY - newHeight
            frame.size.height = newHeight
        case .nw:
            let newWidth = max(minSize, original.width - delta.x)
            frame.origin.x = original.maxX - newWidth
            frame.size.width = newWidth
            let newHeight = max(minSize, original.height - delta.y)
            frame.origin.y = original.maxY - newHeight
            frame.size.height = newHeight
        }
        
        return frame
    }
    
    // MARK: - Selection Helpers
    private func duplicateSelection() {
        guard let graphModel = graphModel else { return }
        graphModel.duplicateSelection(offset: CGPoint(x: 20, y: 20))
    }
    
    private func copySelection() {
        // TODO: Implement clipboard
    }
    
    private func pasteAtCursor() {
        // TODO: Implement paste
    }
    
    private func cutSelection() {
        copySelection()
        graphModel?.deleteSelection()
    }
    
    private func cycleNodeSelection(reverse: Bool) {
        guard let graphModel = graphModel else { return }
        let nodes = graphModel.nodes
        guard !nodes.isEmpty else { return }
        
        if let currentId = graphModel.selectedNodeIds.first,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = reverse ?
                (currentIndex - 1 + nodes.count) % nodes.count :
                (currentIndex + 1) % nodes.count
            graphModel.selectNode(nodes[nextIndex].id, addToSelection: false)
        } else {
            graphModel.selectNode(nodes[0].id, addToSelection: false)
        }
    }
    
    private func selectAtKeyboardCursor() {
        guard let graphModel = graphModel else { return }
        
        for node in graphModel.nodes.reversed() {
            let frame = CGRect(origin: node.position, size: node.size)
            if frame.contains(keyboardCursor) {
                graphModel.selectNode(node.id, addToSelection: modifiers.contains(.shift))
                return
            }
        }
    }
    
    // MARK: - Zoom Controls
    private func zoomIn() {
        guard let graphModel = graphModel else { return }
        withAnimation(.spring(response: 0.3)) {
            graphModel.viewportZoom = min(5.0, graphModel.viewportZoom * 1.25)
        }
    }
    
    private func zoomOut() {
        guard let graphModel = graphModel else { return }
        withAnimation(.spring(response: 0.3)) {
            graphModel.viewportZoom = max(0.1, graphModel.viewportZoom / 1.25)
        }
    }
    
    private func resetZoom() {
        guard let graphModel = graphModel else { return }
        withAnimation(.spring(response: 0.3)) {
            graphModel.viewportZoom = 1.0
            graphModel.viewportOffset = .zero
        }
    }
    
    private func zoomToFit() {
        guard let graphModel = graphModel, !graphModel.nodes.isEmpty else { return }
        
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        
        for node in graphModel.nodes {
            minX = min(minX, node.position.x)
            minY = min(minY, node.position.y)
            maxX = max(maxX, node.position.x + node.size.width)
            maxY = max(maxY, node.position.y + node.size.height)
        }
        
        let contentWidth = maxX - minX + 100
        let contentHeight = maxY - minY + 100
        let viewportWidth: CGFloat = 800 // Approximate
        let viewportHeight: CGFloat = 600
        
        let zoom = min(viewportWidth / contentWidth, viewportHeight / contentHeight, 1.0)
        
        withAnimation(.spring(response: 0.4)) {
            graphModel.viewportZoom = zoom
            graphModel.viewportOffset = CGPoint(
                x: -minX * zoom + (viewportWidth - contentWidth * zoom) / 2,
                y: -minY * zoom + (viewportHeight - contentHeight * zoom) / 2
            )
        }
    }
    
    private func zoomToSelection() {
        guard let graphModel = graphModel, !graphModel.selectedNodeIds.isEmpty else { return }
        
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        
        for nodeId in graphModel.selectedNodeIds {
            guard let node = graphModel.getNode(nodeId) else { continue }
            minX = min(minX, node.position.x)
            minY = min(minY, node.position.y)
            maxX = max(maxX, node.position.x + node.size.width)
            maxY = max(maxY, node.position.y + node.size.height)
        }
        
        let contentWidth = maxX - minX + 100
        let contentHeight = maxY - minY + 100
        let viewportWidth: CGFloat = 800
        let viewportHeight: CGFloat = 600
        
        let zoom = min(viewportWidth / contentWidth, viewportHeight / contentHeight, 2.0)
        
        withAnimation(.spring(response: 0.4)) {
            graphModel.viewportZoom = zoom
            graphModel.viewportOffset = CGPoint(
                x: -minX * zoom + (viewportWidth - contentWidth * zoom) / 2,
                y: -minY * zoom + (viewportHeight - contentHeight * zoom) / 2
            )
        }
    }
}
