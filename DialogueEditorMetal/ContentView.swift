import SwiftUI

struct ContentView: View {
    @EnvironmentObject var graphModel: GraphModel
    @State private var showingProperties = true
    @State private var showingPalette = true
    @State private var isWritingMode = false
    @State private var showingInlineEditor = false
    @State private var inlineEditorNode: DialogueNode?
    @State private var inlineEditorPosition: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Main editor or writing mode
            if isWritingMode {
                WritingModeView(isWritingMode: $isWritingMode)
            } else {
                mainEditorView
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
        .background(Color(hex: "1a1a2e"))
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
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
        .background(Color(hex: "16162a"))
    }
}

struct PaletteSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 4)
            
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
            // Add node at center of viewport (using world coordinates)
            let worldCenter = CGPoint(
                x: -graphModel.viewportOffset.x / graphModel.viewportZoom + 400 / graphModel.viewportZoom,
                y: -graphModel.viewportOffset.y / graphModel.viewportZoom + 300 / graphModel.viewportZoom
            )
            graphModel.addNode(type: type, at: worldCenter)
        } label: {
            HStack(spacing: 10) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(type.color)
                    .frame(width: 3, height: 20)
                
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(type.color)
                    .frame(width: 20)
                
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
                
                // Keyboard shortcut hint (always visible, no layout shift)
                if let shortcut = type.keyboardShortcut {
                    Text(shortcut)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? type.color.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(type.fullDescription)
    }
}

struct RenderStatsView: View {
    @EnvironmentObject var graphModel: GraphModel
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("GPU: M3 Max")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            Text("\(graphModel.nodes.count) nodes · \(graphModel.connections.count) connections")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.4))
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.4))
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GraphModel())
            .frame(width: 1200, height: 800)
    }
}
#endif
