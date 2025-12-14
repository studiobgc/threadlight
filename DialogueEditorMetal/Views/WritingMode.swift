import SwiftUI

/// Distraction-free writing mode inspired by the Disco Elysium workflow
/// "It is so much fun like just creating more and more and more"
struct WritingModeView: View {
    @EnvironmentObject var graphModel: GraphModel
    @Binding var isWritingMode: Bool
    
    @State private var currentNodeId: UUID?
    @State private var flowHistory: [UUID] = []  // Breadcrumb trail
    @State private var showLore = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color(hex: "0f0f1a")
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    // Main writing area
                    VStack(spacing: 0) {
                        // Minimal header
                        WritingModeHeader(
                            isWritingMode: $isWritingMode,
                            showLore: $showLore,
                            graphName: graphModel.graphInfo.name,
                            nodeCount: graphModel.nodes.count
                        )
                        
                        // Flow breadcrumbs
                        if !flowHistory.isEmpty {
                            FlowBreadcrumbs(
                                history: flowHistory,
                                nodes: graphModel.nodes,
                                onSelect: { navigateToNode($0) }
                            )
                        }
                        
                        // Current node editor
                        if let nodeId = currentNodeId,
                           let node = graphModel.getNode(nodeId) {
                            WritingNodeEditor(
                                node: node,
                                characters: graphModel.characters,
                                onContinue: { type, speakerId in
                                    createNextNode(from: node, type: type, speakerId: speakerId)
                                },
                                onNavigateBack: { navigateBack() },
                                onNavigateForward: { navigateToConnection($0) }
                            )
                        } else {
                            // Empty state - start writing
                            WritingEmptyState(onCreateFirst: createFirstNode)
                        }
                        
                        Spacer()
                    }
                    
                    // Lore sidebar (optional)
                    if showLore {
                        Divider().background(Color.white.opacity(0.1))
                        
                        LoreSidebar(graphModel: graphModel)
                            .frame(width: 300)
                    }
                }
            }
        }
        .onAppear {
            // Start at the last selected node or the first dialogue node
            if let selectedId = graphModel.selectedNodeIds.first {
                currentNodeId = selectedId
            } else if let firstDialogue = graphModel.nodes.first(where: { $0.nodeType.isDialogueType }) {
                currentNodeId = firstDialogue.id
            }
        }
    }
    
    private func createFirstNode() {
        let node = graphModel.addNode(type: .dialogue, at: CGPoint(x: 200, y: 200))
        currentNodeId = node.id
        flowHistory.append(node.id)
    }
    
    private func createNextNode(from sourceNode: DialogueNode, type: NodeType, speakerId: UUID?) {
        // Position new node to the right
        let newPosition = CGPoint(
            x: sourceNode.position.x + sourceNode.size.width + 80,
            y: sourceNode.position.y
        )
        
        let newNode = graphModel.addNode(type: type, at: newPosition)
        
        // Set speaker if provided
        if let speakerId = speakerId {
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
        graphModel.addConnection(from: sourceNode.id, fromPort: 0, to: newNode.id, toPort: 0)
        
        // Navigate to new node
        flowHistory.append(sourceNode.id)
        currentNodeId = newNode.id
    }
    
    private func navigateToNode(_ id: UUID) {
        if let index = flowHistory.firstIndex(of: id) {
            flowHistory = Array(flowHistory.prefix(index + 1))
        }
        currentNodeId = id
    }
    
    private func navigateBack() {
        guard flowHistory.count > 0 else { return }
        if let currentId = currentNodeId {
            // Find incoming connections
            if let incoming = graphModel.connections.first(where: { $0.toNodeId == currentId }) {
                currentNodeId = incoming.fromNodeId
                if flowHistory.last != incoming.fromNodeId {
                    flowHistory.append(incoming.fromNodeId)
                }
            }
        }
    }
    
    private func navigateToConnection(_ index: Int) {
        guard let currentId = currentNodeId else { return }
        
        let outgoing = graphModel.connections.filter { $0.fromNodeId == currentId }
        if index < outgoing.count {
            flowHistory.append(currentId)
            currentNodeId = outgoing[index].toNodeId
        }
    }
}

struct WritingModeHeader: View {
    @Binding var isWritingMode: Bool
    @Binding var showLore: Bool
    let graphName: String
    let nodeCount: Int
    
    var body: some View {
        HStack {
            // Exit writing mode
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isWritingMode = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("Exit")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Graph info
            VStack(spacing: 2) {
                Text(graphName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("\(nodeCount) nodes")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Toggle lore
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showLore.toggle()
                }
            } label: {
                Image(systemName: "book.closed")
                    .font(.system(size: 14))
                    .foregroundColor(showLore ? Color(hex: "7c3aed") : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

struct FlowBreadcrumbs: View {
    let history: [UUID]
    let nodes: [DialogueNode]
    let onSelect: (UUID) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            breadcrumbStack
        }
    }
    
    private var breadcrumbStack: some View {
        HStack(spacing: 4) {
            ForEach(recentHistory, id: \.self) { nodeId in
                breadcrumbItem(for: nodeId)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private var recentHistory: [UUID] {
        Array(history.suffix(5))
    }
    
    @ViewBuilder
    private func breadcrumbItem(for nodeId: UUID) -> some View {
        if let node = nodes.first(where: { $0.id == nodeId }) {
            BreadcrumbButton(node: node, onSelect: { onSelect(nodeId) })
            
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

struct BreadcrumbButton: View {
    let node: DialogueNode
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Circle()
                    .fill(node.nodeType.color)
                    .frame(width: 6, height: 6)
                
                Text(displayText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
    
    private var displayText: String {
        if let text = node.data.displayText {
            return String(text.prefix(20))
        }
        return node.technicalName
    }
}

struct WritingNodeEditor: View {
    @ObservedObject var node: DialogueNode
    let characters: [Character]
    let onContinue: (NodeType, UUID?) -> Void
    let onNavigateBack: () -> Void
    let onNavigateForward: (Int) -> Void
    
    @State private var text: String = ""
    @State private var selectedSpeakerId: UUID?
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Node type indicator
            HStack {
                Image(systemName: node.nodeType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(node.nodeType.color)
                
                Text(node.nodeType.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(node.nodeType.color.opacity(0.8))
                
                Spacer()
                
                // Navigation arrows
                HStack(spacing: 12) {
                    Button(action: onNavigateBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    
                    Button { onNavigateForward(0) } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            
            // Speaker selector for dialogue nodes
            if node.nodeType.isDialogueType {
                WritingModeSpeakerSelector(
                    selectedId: $selectedSpeakerId,
                    characters: characters
                )
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            
            // Main text area - big and focused
            TextEditor(text: $text)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .focused($isTextFocused)
                .frame(maxWidth: 700)
                .frame(minHeight: 200)
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .onChange(of: text) { _, newValue in
                    updateNodeText(newValue)
                }
            
            // Quick continue bar
            HStack(spacing: 16) {
                // Continue with same speaker
                if let speaker = characters.first(where: { $0.id == selectedSpeakerId }) {
                    ContinueButton(
                        label: "Continue as \(speaker.name)",
                        shortcut: "Tab",
                        color: Color(hex: speaker.color)
                    ) {
                        onContinue(.dialogueFragment, speaker.id)
                    }
                }
                
                // Change speaker
                ForEach(characters.filter { $0.id != selectedSpeakerId }.prefix(3)) { character in
                    ContinueButton(
                        label: character.name,
                        shortcut: nil,
                        color: Color(hex: character.color)
                    ) {
                        onContinue(.dialogueFragment, character.id)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Structure nodes
                ContinueButton(label: "Branch", shortcut: "B", color: NodeType.branch.color) {
                    onContinue(.branch, nil)
                }
                
                ContinueButton(label: "Check", shortcut: "W", color: NodeType.whiteCheck.color) {
                    onContinue(.whiteCheck, nil)
                }
                
                ContinueButton(label: "Thought", shortcut: "T", color: NodeType.thought.color) {
                    onContinue(.thought, nil)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .onAppear {
            loadNodeData()
            isTextFocused = true
        }
    }
    
    // Tab handler moved to separate function to avoid ambiguity
    private func handleTabKey() {
        if let speakerId = selectedSpeakerId {
            onContinue(.dialogueFragment, speakerId)
        } else {
            onContinue(.dialogueFragment, nil)
        }
    }
    
    private func loadNodeData() {
        switch node.data {
        case .dialogue(let data), .dialogueFragment(let data):
            text = data.text
            selectedSpeakerId = data.speakerId
        case .thought(let data):
            text = data.text
        default:
            break
        }
    }
    
    private func updateNodeText(_ newText: String) {
        switch node.data {
        case .dialogue(var data):
            data.text = newText
            data.speakerId = selectedSpeakerId
            node.data = .dialogue(data)
        case .dialogueFragment(var data):
            data.text = newText
            data.speakerId = selectedSpeakerId
            node.data = .dialogueFragment(data)
        case .thought(var data):
            data.text = newText
            node.data = .thought(data)
        default:
            break
        }
    }
}

struct WritingModeSpeakerSelector: View {
    @Binding var selectedId: UUID?
    let characters: [Character]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(characters) { character in
                Button {
                    selectedId = character.id
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: character.color))
                            .frame(width: 8, height: 8)
                        
                        Text(character.name)
                            .font(.system(size: 13, weight: selectedId == character.id ? .semibold : .regular))
                    }
                    .foregroundColor(selectedId == character.id ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedId == character.id ? Color(hex: character.color).opacity(0.3) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
}

struct ContinueButton: View {
    let label: String
    let shortcut: String?
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WritingEmptyState: View {
    let onCreateFirst: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.cursor")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
            
            Text("Start writing")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Press Enter or click below to create your first dialogue node")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
            
            Button(action: onCreateFirst) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create First Node")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "7c3aed"))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoreSidebar: View {
    @ObservedObject var graphModel: GraphModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LORE & REFERENCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider().background(Color.white.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Characters section
                    LoreSection(title: "Characters", icon: "person.2.fill") {
                        ForEach(graphModel.characters) { character in
                            HStack {
                                Circle()
                                    .fill(Color(hex: character.color))
                                    .frame(width: 10, height: 10)
                                
                                Text(character.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Variables section
                    LoreSection(title: "Variables", icon: "function") {
                        Text("No variables defined")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    // Notes section
                    LoreSection(title: "Notes", icon: "note.text") {
                        Text("Add world-building notes here...")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "12121f"))
    }
}

struct LoreSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content
                    .padding(.leading, 20)
            }
        }
    }
}

#if DEBUG
struct WritingModeView_Previews: PreviewProvider {
    static var previews: some View {
        WritingModeView(isWritingMode: .constant(true))
            .environmentObject(GraphModel())
            .frame(width: 1200, height: 800)
    }
}
#endif
