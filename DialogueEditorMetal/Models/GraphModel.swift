import Foundation
import SwiftUI
import Combine

struct Character: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: String           // Hex color for visual identification
    var shortName: String?      // 2-3 letter abbreviation
    var description: String?    // Character bio / notes
    var voiceStyle: String?     // Notes on how they speak
    var portrait: String?       // Image asset name
    
    // Disco Elysium-style "internal voice" for thoughts
    var isInternalVoice: Bool   // Like DE's skills talking to you
    var internalVoiceType: InternalVoiceType?
    
    enum InternalVoiceType: String, Codable {
        case logic          // Analytical, deductive
        case empathy        // Emotional intelligence
        case authority      // Commanding presence
        case drama          // Theatrical flair
        case rhetoric       // Persuasive speech
        case suggestion     // Subtle influence
        case composure      // Emotional control
        case volition       // Willpower
        case physique       // Physical awareness
        case electrochemistry // Pleasure/addiction
        case custom         // User-defined
    }
    
    init(name: String, color: String = "#3b82f6", isInternal: Bool = false) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isInternalVoice = isInternal
    }
    
    // Predefined internal voices (like Disco Elysium skills)
    static let internalVoices: [Character] = [
        Character(name: "Logic", color: "#60a5fa", isInternal: true),
        Character(name: "Empathy", color: "#f472b6", isInternal: true),
        Character(name: "Drama", color: "#c084fc", isInternal: true),
        Character(name: "Volition", color: "#fbbf24", isInternal: true),
        Character(name: "Rhetoric", color: "#34d399", isInternal: true),
    ]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
}

struct DialogueGraph: Codable {
    var id: UUID
    var name: String
    var technicalName: String
    var createdAt: Date
    var modifiedAt: Date
}

class GraphModel: ObservableObject {
    @Published var nodes: [DialogueNode] = []
    @Published var connections: [Connection] = []
    @Published var characters: [Character] = []
    @Published var internalVoices: [Character] = Character.internalVoices
    @Published var selectedNodeIds: Set<UUID> = []
    @Published var selectedConnectionId: UUID?
    @Published var graphInfo: DialogueGraph
    
    // Viewport state
    @Published var viewportOffset: CGPoint = .zero
    @Published var viewportZoom: CGFloat = 1.0
    
    // Writing mode state
    @Published var isWritingMode: Bool = false
    @Published var currentWritingNodeId: UUID?
    @Published var writingFlowHistory: [UUID] = []
    
    // Undo/Redo
    private var undoStack: [Data] = []
    private var redoStack: [Data] = []
    private let maxUndoSteps = 100
    
    init() {
        self.graphInfo = DialogueGraph(
            id: UUID(),
            name: "Untitled Graph",
            technicalName: "untitled_graph",
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // Add some default characters for demo
        addCharacter(name: "Player", color: "#3b82f6")
        addCharacter(name: "NPC", color: "#10b981")
    }
    
    // MARK: - Node Operations
    
    @discardableResult
    func addNode(type: NodeType, at position: CGPoint, name: String? = nil) -> DialogueNode {
        saveUndoState()
        
        // Convert screen position to world position
        let worldPos = screenToWorld(position)
        let node = DialogueNode(type: type, position: worldPos, name: name)
        nodes.append(node)
        graphInfo.modifiedAt = Date()
        
        // Auto-select new node
        selectedNodeIds = [node.id]
        
        return node
    }
    
    func removeNode(_ id: UUID) {
        saveUndoState()
        
        // Remove all connections to/from this node
        connections.removeAll { $0.fromNodeId == id || $0.toNodeId == id }
        
        // Remove the node
        nodes.removeAll { $0.id == id }
        selectedNodeIds.remove(id)
        graphInfo.modifiedAt = Date()
    }
    
    func deleteSelectedNodes() {
        saveUndoState()
        
        for id in selectedNodeIds {
            connections.removeAll { $0.fromNodeId == id || $0.toNodeId == id }
            nodes.removeAll { $0.id == id }
        }
        selectedNodeIds.removeAll()
        graphInfo.modifiedAt = Date()
    }
    
    func updateNodePosition(_ id: UUID, to position: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].position = position
        graphInfo.modifiedAt = Date()
    }
    
    func getNode(_ id: UUID) -> DialogueNode? {
        nodes.first { $0.id == id }
    }
    
    func cloneNode(_ id: UUID, offset: CGPoint = CGPoint(x: 50, y: 50)) -> DialogueNode? {
        guard let original = getNode(id) else { return nil }
        saveUndoState()
        
        let clone = DialogueNode(type: original.nodeType, position: CGPoint(
            x: original.position.x + offset.x,
            y: original.position.y + offset.y
        ))
        clone.data = original.data
        clone.size = original.size
        
        nodes.append(clone)
        graphInfo.modifiedAt = Date()
        return clone
    }
    
    // MARK: - Connection Operations
    
    func canConnect(from fromNodeId: UUID, fromPort: Int, to toNodeId: UUID, toPort: Int) -> Bool {
        // Can't connect to self
        if fromNodeId == toNodeId { return false }
        
        // Check if connection already exists
        let exists = connections.contains {
            $0.fromNodeId == fromNodeId &&
            $0.fromPortIndex == fromPort &&
            $0.toNodeId == toNodeId &&
            $0.toPortIndex == toPort
        }
        if exists { return false }
        
        // Check if nodes exist and ports are valid
        guard let fromNode = getNode(fromNodeId),
              let toNode = getNode(toNodeId),
              fromPort < fromNode.outputPorts.count,
              toPort < toNode.inputPorts.count else {
            return false
        }
        
        // Check if input port is already connected (single input rule)
        let inputTaken = connections.contains {
            $0.toNodeId == toNodeId && $0.toPortIndex == toPort
        }
        if inputTaken { return false }
        
        return true
    }
    
    @discardableResult
    func addConnection(from fromNodeId: UUID, fromPort: Int, to toNodeId: UUID, toPort: Int) -> Connection? {
        guard canConnect(from: fromNodeId, fromPort: fromPort, to: toNodeId, toPort: toPort) else {
            return nil
        }
        
        saveUndoState()
        let connection = Connection(from: fromNodeId, fromPort: fromPort, to: toNodeId, toPort: toPort)
        connections.append(connection)
        graphInfo.modifiedAt = Date()
        return connection
    }
    
    func removeConnection(_ id: UUID) {
        saveUndoState()
        connections.removeAll { $0.id == id }
        if selectedConnectionId == id {
            selectedConnectionId = nil
        }
        graphInfo.modifiedAt = Date()
    }
    
    func getConnectionsFor(nodeId: UUID) -> [Connection] {
        connections.filter { $0.fromNodeId == nodeId || $0.toNodeId == nodeId }
    }
    
    // MARK: - Selection
    
    func selectNode(_ id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            selectedNodeIds.insert(id)
        } else {
            selectedNodeIds = [id]
        }
        selectedConnectionId = nil
        
        // Update node states
        for node in nodes {
            node.isSelected = selectedNodeIds.contains(node.id)
        }
    }
    
    func selectNodes(_ ids: Set<UUID>) {
        selectedNodeIds = ids
        selectedConnectionId = nil
        
        for node in nodes {
            node.isSelected = selectedNodeIds.contains(node.id)
        }
    }
    
    func selectConnection(_ id: UUID) {
        selectedConnectionId = id
        selectedNodeIds.removeAll()
        
        for node in nodes {
            node.isSelected = false
        }
    }
    
    func clearSelection() {
        selectedNodeIds.removeAll()
        selectedConnectionId = nil
        
        for node in nodes {
            node.isSelected = false
        }
    }
    
    func getSelectedNodes() -> [DialogueNode] {
        nodes.filter { selectedNodeIds.contains($0.id) }
    }
    
    func selectAll() {
        selectedNodeIds = Set(nodes.map { $0.id })
        selectedConnectionId = nil
        for node in nodes {
            node.isSelected = true
        }
    }
    
    func deleteSelection() {
        guard !selectedNodeIds.isEmpty || selectedConnectionId != nil else { return }
        saveUndoState()
        
        // Delete selected connection
        if let connId = selectedConnectionId {
            connections.removeAll { $0.id == connId }
            selectedConnectionId = nil
        }
        
        // Delete selected nodes and their connections
        for id in selectedNodeIds {
            connections.removeAll { $0.fromNodeId == id || $0.toNodeId == id }
            nodes.removeAll { $0.id == id }
        }
        selectedNodeIds.removeAll()
        graphInfo.modifiedAt = Date()
    }
    
    @discardableResult
    func duplicateSelection(offset: CGPoint = CGPoint(x: 20, y: 20)) -> [DialogueNode] {
        guard !selectedNodeIds.isEmpty else { return [] }
        saveUndoState()
        
        var newNodes: [DialogueNode] = []
        var idMapping: [UUID: UUID] = [:]
        
        // Clone nodes
        for nodeId in selectedNodeIds {
            guard let original = getNode(nodeId) else { continue }
            let clone = DialogueNode(type: original.nodeType, position: CGPoint(
                x: original.position.x + offset.x,
                y: original.position.y + offset.y
            ))
            clone.data = original.data
            clone.size = original.size
            nodes.append(clone)
            newNodes.append(clone)
            idMapping[nodeId] = clone.id
        }
        
        // Clone connections between selected nodes
        for connection in connections {
            if let newFromId = idMapping[connection.fromNodeId],
               let newToId = idMapping[connection.toNodeId] {
                let newConnection = Connection(
                    from: newFromId,
                    fromPort: connection.fromPortIndex,
                    to: newToId,
                    toPort: connection.toPortIndex
                )
                connections.append(newConnection)
            }
        }
        
        // Select new nodes
        selectedNodeIds = Set(newNodes.map { $0.id })
        for node in nodes {
            node.isSelected = selectedNodeIds.contains(node.id)
        }
        
        graphInfo.modifiedAt = Date()
        return newNodes
    }
    
    // MARK: - Viewport
    
    func screenToWorld(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - viewportOffset.x) / viewportZoom,
            y: (point.y - viewportOffset.y) / viewportZoom
        )
    }
    
    func worldToScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * viewportZoom + viewportOffset.x,
            y: point.y * viewportZoom + viewportOffset.y
        )
    }
    
    // MARK: - Graph Operations
    
    func newGraph(name: String = "Untitled Graph") {
        saveUndoState()
        nodes.removeAll()
        connections.removeAll()
        characters.removeAll()
        selectedNodeIds.removeAll()
        selectedConnectionId = nil
        viewportOffset = .zero
        viewportZoom = 1.0
        
        graphInfo = DialogueGraph(
            id: UUID(),
            name: name,
            technicalName: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            createdAt: Date(),
            modifiedAt: Date()
        )
    }
    
    // MARK: - Undo/Redo
    
    func saveUndoState() {
        // Encode current state
        let state = GraphState(nodes: nodes, connections: connections, characters: characters)
        if let data = try? JSONEncoder().encode(state) {
            undoStack.append(data)
            if undoStack.count > maxUndoSteps {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
        }
    }
    
    func undo() {
        guard let lastState = undoStack.popLast() else { return }
        
        // Save current state to redo
        let currentState = GraphState(nodes: nodes, connections: connections, characters: characters)
        if let data = try? JSONEncoder().encode(currentState) {
            redoStack.append(data)
        }
        
        // Restore previous state
        if let state = try? JSONDecoder().decode(GraphState.self, from: lastState) {
            nodes = state.nodes
            connections = state.connections
            characters = state.characters
        }
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        
        // Save current state to undo
        let currentState = GraphState(nodes: nodes, connections: connections, characters: characters)
        if let data = try? JSONEncoder().encode(currentState) {
            undoStack.append(data)
        }
        
        // Apply redo state
        if let state = try? JSONDecoder().decode(GraphState.self, from: nextState) {
            nodes = state.nodes
            connections = state.connections
            characters = state.characters
        }
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // MARK: - Character Operations
    
    @discardableResult
    func addCharacter(name: String, color: String = "#3b82f6", isInternal: Bool = false) -> Character {
        let character = Character(name: name, color: color, isInternal: isInternal)
        if isInternal {
            internalVoices.append(character)
        } else {
            characters.append(character)
        }
        graphInfo.modifiedAt = Date()
        return character
    }
    
    func removeCharacter(_ id: UUID) {
        characters.removeAll { $0.id == id }
        internalVoices.removeAll { $0.id == id }
        graphInfo.modifiedAt = Date()
    }
    
    func getCharacter(_ id: UUID) -> Character? {
        characters.first { $0.id == id } ?? internalVoices.first { $0.id == id }
    }
    
    var allVoices: [Character] {
        characters + internalVoices
    }
    
    // MARK: - Flow-First Writing Helpers
    
    /// Create a node connected to the source, positioned to its right
    @discardableResult
    func createConnectedNode(from sourceId: UUID, type: NodeType, speakerId: UUID? = nil) -> DialogueNode? {
        guard let sourceNode = getNode(sourceId) else { return nil }
        
        // Position new node to the right of source
        let newPosition = CGPoint(
            x: sourceNode.position.x + sourceNode.size.width + 80,
            y: sourceNode.position.y
        )
        
        let newNode = addNode(type: type, at: newPosition)
        
        // Set speaker if provided and applicable
        if let speakerId = speakerId, type.isDialogueType {
            switch newNode.data {
            case .dialogue(var data):
                data.speakerId = speakerId
                newNode.data = .dialogue(data)
            case .dialogueFragment(var data):
                data.speakerId = speakerId
                newNode.data = .dialogueFragment(data)
            default:
                break
            }
        }
        
        // Connect nodes
        addConnection(from: sourceId, fromPort: 0, to: newNode.id, toPort: 0)
        
        // Select new node
        selectNode(newNode.id)
        
        return newNode
    }
    
    /// Get the speaker from the last dialogue node in a chain
    func getLastSpeaker(from nodeId: UUID) -> Character? {
        guard let node = getNode(nodeId) else { return nil }
        
        switch node.data {
        case .dialogue(let data), .dialogueFragment(let data):
            if let speakerId = data.speakerId {
                return getCharacter(speakerId)
            }
        default:
            break
        }
        
        // Look at incoming connections for context
        if let incoming = connections.first(where: { $0.toNodeId == nodeId }) {
            return getLastSpeaker(from: incoming.fromNodeId)
        }
        
        return nil
    }
}

private struct GraphState: Codable {
    let nodes: [DialogueNode]
    let connections: [Connection]
    let characters: [Character]
}
