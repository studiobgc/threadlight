import SwiftUI

struct ContentView: View {
    @EnvironmentObject var graphModel: GraphModel
    @State private var showingProperties = true
    @State private var showingPalette = true
    @State private var isWritingMode = false
    @State private var showingInlineEditor = false
    @State private var inlineEditorNode: DialogueNode?
    @State private var inlineEditorPosition: CGPoint = .zero
    @State private var showingShortcuts = false
    
    var body: some View {
        ZStack {
            // Main editor or writing mode
            if isWritingMode {
                WritingModeView(isWritingMode: $isWritingMode)
            } else {
                mainEditorView
            }
            
            // Shortcuts overlay (press ? to show)
            if showingShortcuts {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showingShortcuts = false }
                ShortcutsOverlay(isShowing: $showingShortcuts)
            }
            
            // Inline editor overlay
            if showingInlineEditor, let node = inlineEditorNode {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingInlineEditor = false
                    }
                
                InlineEditor(
                    node: node,
                    screenPosition: inlineEditorPosition,
                    canvasRect: .zero,
                    onClose: {
                        showingInlineEditor = false
                    },
                    onCreateNext: { type in
                        if let newNode = graphModel.createConnectedNode(from: node.id, type: type) {
                            inlineEditorNode = newNode
                            inlineEditorPosition.x += 200
                        }
                    }
                )
            }
        }
    }
    
    var mainEditorView: some View {
        HSplitView {
            // Left: Node Palette
            if showingPalette {
                NodePalette()
                    .frame(minWidth: 200, maxWidth: 250)
            }
            
            // Center: Metal Canvas
            VStack(spacing: 0) {
                EditorToolbar(
                    showingPalette: $showingPalette,
                    showingProperties: $showingProperties,
                    isWritingMode: $isWritingMode
                )
                
                ZStack {
                    NodeEditorView()
                    
                    // Floating stats overlay
                    VStack {
                        HStack {
                            Spacer()
                            RenderStatsView()
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 600)
            
            // Right: Properties Panel
            if showingProperties {
                PropertiesPanel()
                    .frame(minWidth: 280, maxWidth: 350)
            }
        }
        .background(DS.Colors.bg0)
        .preferredColorScheme(.dark)
    }
}

struct NodePalette: View {
    @EnvironmentObject var graphModel: GraphModel
    
    // Organized by category for better UX
    let dialogueTypes: [(NodeType, String, String)] = [
        (.dialogue, "bubble.left.fill", "Dialogue"),
        (.dialogueFragment, "text.bubble.fill", "Fragment"),
        (.thought, "brain.head.profile", "Thought"),
    ]
    
    let structureTypes: [(NodeType, String, String)] = [
        (.branch, "arrow.triangle.branch", "Branch"),
        (.hub, "circle.hexagongrid.fill", "Hub"),
        (.jump, "arrow.uturn.right", "Jump"),
    ]
    
    let logicTypes: [(NodeType, String, String)] = [
        (.condition, "questionmark.diamond.fill", "Condition"),
        (.instruction, "gearshape.fill", "Instruction"),
    ]
    
    // Disco Elysium-style skill checks
    let checkTypes: [(NodeType, String, String)] = [
        (.whiteCheck, "dice.fill", "White Check"),
        (.redCheck, "exclamationmark.triangle.fill", "Red Check"),
        (.passiveCheck, "eye.fill", "Passive"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NODES")
                .font(DS.Font.label)
                .foregroundColor(DS.Colors.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Dialogue nodes
                    PaletteSection(title: "DIALOGUE") {
                        ForEach(dialogueTypes, id: \.0) { type, icon, name in
                            PaletteItem(type: type, icon: icon, name: name)
                        }
                    }
                    
                    // Skill checks (Disco Elysium style)
                    PaletteSection(title: "SKILL CHECKS") {
                        ForEach(checkTypes, id: \.0) { type, icon, name in
                            PaletteItem(type: type, icon: icon, name: name)
                        }
                    }
                    
                    // Structure nodes
                    PaletteSection(title: "STRUCTURE") {
                        ForEach(structureTypes, id: \.0) { type, icon, name in
                            PaletteItem(type: type, icon: icon, name: name)
                        }
                    }
                    
                    // Logic nodes
                    PaletteSection(title: "LOGIC") {
                        ForEach(logicTypes, id: \.0) { type, icon, name in
                            PaletteItem(type: type, icon: icon, name: name)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Quick stats
            VStack(alignment: .leading, spacing: 8) {
                Text("GRAPH")
                    .font(DS.Font.label)
                    .foregroundColor(DS.Colors.text2)
                
                HStack {
                    Label("\(graphModel.nodes.count)", systemImage: "square.stack.3d.up")
                    Spacer()
                    Label("\(graphModel.connections.count)", systemImage: "link")
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
        }
        .background(DS.Colors.bg1)
    }
}

struct PaletteSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title)
                .font(DS.Font.label)
                .foregroundColor(DS.Colors.text3)
                .padding(.horizontal, DS.Space.xs)
            
            content
        }
    }
}

struct PaletteItem: View {
    @EnvironmentObject var graphModel: GraphModel
    let type: NodeType
    let icon: String
    let name: String
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            let worldCenter = CGPoint(
                x: -graphModel.viewportOffset.x / graphModel.viewportZoom + 400 / graphModel.viewportZoom,
                y: -graphModel.viewportOffset.y / graphModel.viewportZoom + 300 / graphModel.viewportZoom
            )
            graphModel.addNode(type: type, at: worldCenter)
        } label: {
            HStack(spacing: DS.Space.sm) {
                // Color dot
                Circle()
                    .fill(type.color)
                    .frame(width: 6, height: 6)
                
                Text(name)
                    .font(DS.Font.body)
                    .foregroundColor(isHovered ? DS.Colors.text0 : DS.Colors.text1)
                
                Spacer()
                
                if let shortcut = type.keyboardShortcut {
                    Text(shortcut)
                        .font(DS.Font.code)
                        .foregroundColor(DS.Colors.text3)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(isHovered ? DS.Colors.bg2 : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(type.fullDescription)
    }
}

struct RenderStatsView: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        HStack(spacing: DS.Space.md) {
            Text("\(graphModel.nodes.count)n")
            Text("\(graphModel.connections.count)c")
        }
        .font(DS.Font.code)
        .foregroundColor(DS.Colors.text3)
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(DS.Colors.bg1.opacity(0.9))
        .cornerRadius(DS.Radius.sm)
    }
}

// Color extension moved to DesignSystem.swift

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GraphModel())
            .frame(width: 1200, height: 800)
    }
}
#endif
// MARK: - Keyboard Shortcuts Overlay

struct ShortcutsOverlay: View {
    @Binding var isShowing: Bool
    
    let shortcuts: [(String, String, String)] = [
        // Category, Key, Action
        ("CREATE", "D", "New Dialogue"),
        ("CREATE", "B", "New Branch"),
        ("CREATE", "C", "New Condition"),
        ("", "", ""),
        ("NAVIGATE", "Arrow Keys", "Nudge / Pan"),
        ("NAVIGATE", "Space + Drag", "Pan canvas"),
        ("NAVIGATE", "Scroll", "Pan"),
        ("NAVIGATE", "⌘ + Scroll", "Zoom"),
        ("NAVIGATE", "Pinch", "Zoom"),
        ("", "", ""),
        ("EDIT", "⌘Z", "Undo"),
        ("EDIT", "⌘⇧Z", "Redo"),
        ("EDIT", "⌘A", "Select All"),
        ("EDIT", "⌘D", "Duplicate"),
        ("EDIT", "Delete", "Delete selected"),
        ("", "", ""),
        ("WORKFLOW", "⌃⇧1", "Smart Create (connected node)"),
        ("WORKFLOW", "⌥←/→", "Jump to connected node"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("KEYBOARD SHORTCUTS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Press ? to toggle")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                Button { isShowing = false } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(hex: "ff6633"))
            
            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                        if shortcut.0.isEmpty {
                            Divider().padding(.vertical, 8)
                        } else {
                            ShortcutRow(category: shortcut.0, key: shortcut.1, action: shortcut.2)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 420)
        .background(Color(hex: "101012"))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
}

struct ShortcutRow: View {
    let category: String
    let key: String
    let action: String
    
    var body: some View {
        HStack {
            Text(category)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 70, alignment: .leading)
            
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "ff6633"))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "ff6633").opacity(0.15))
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)
            
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}
