import SwiftUI

/// Figma-style inline editor that appears directly over nodes
/// Double-click a dialogue node to start typing immediately
struct InlineEditor: View {
    @EnvironmentObject var graphModel: GraphModel
    
    let node: DialogueNode
    let screenPosition: CGPoint
    let canvasRect: CGRect
    let onClose: () -> Void
    let onCreateNext: (NodeType) -> Void
    
    @State private var text: String = ""
    @State private var selectedSpeakerId: UUID?
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Speaker selector (compact)
            if node.nodeType.isDialogueType {
                SpeakerSelector(
                    selectedId: $selectedSpeakerId,
                    characters: graphModel.characters,
                    nodeColor: node.nodeType.color
                )
            }
            
            // Main text editor
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFocused)
                    .frame(minHeight: 60, maxHeight: 200)
                    .onChange(of: text) { _, newValue in
                        updateNodeText(newValue)
                    }
            }
            .padding(8)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Quick actions bar
            HStack(spacing: 4) {
                // Continue shortcuts
                QuickActionButton(icon: "arrow.right", label: "Tab") {
                    saveAndCreateNext(.dialogueFragment)
                }
                
                QuickActionButton(icon: "arrow.triangle.branch", label: "B") {
                    saveAndCreateNext(.branch)
                }
                
                QuickActionButton(icon: "dice.fill", label: "W") {
                    saveAndCreateNext(.whiteCheck)
                }
                
                Spacer()
                
                // Character count
                Text("\(text.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                
                // Close
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: max(node.size.width + 40, 320))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "1e1e2e"))
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(node.nodeType.color.opacity(0.5), lineWidth: 2)
        )
        .position(screenPosition)
        .onAppear {
            loadNodeData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFocused = true
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.tab) {
            saveAndCreateNext(.dialogueFragment)
            return .handled
        }
    }
    
    private var placeholderText: String {
        switch node.nodeType {
        case .dialogue, .dialogueFragment:
            return "What does this character say?"
        case .thought:
            return "What are you thinking?"
        default:
            return "Enter text..."
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
    
    private func saveAndCreateNext(_ type: NodeType) {
        updateNodeText(text)
        onClose()
        onCreateNext(type)
    }
}

struct SpeakerSelector: View {
    @Binding var selectedId: UUID?
    let characters: [Character]
    let nodeColor: Color
    
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Current speaker indicator
            if let speaker = characters.first(where: { $0.id == selectedId }) {
                Circle()
                    .fill(Color(hex: speaker.color))
                    .frame(width: 10, height: 10)
                
                Text(speaker.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 10, height: 10)
                
                Text("No speaker")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Dropdown trigger
            Menu {
                Button("No speaker") {
                    selectedId = nil
                }
                
                Divider()
                
                ForEach(characters) { character in
                    Button {
                        selectedId = character.id
                    } label: {
                        Label(character.name, systemImage: "person.fill")
                    }
                }
                
                Divider()
                
                Button {
                    // TODO: Add new character
                } label: {
                    Label("New Character...", systemImage: "person.badge.plus")
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(nodeColor.opacity(0.2))
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Press \(label) to continue with this node type")
    }
}

#if DEBUG
struct InlineEditor_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "1e1e2e")
            
            InlineEditor(
                node: DialogueNode(type: .dialogue, position: .zero),
                screenPosition: CGPoint(x: 300, y: 300),
                canvasRect: CGRect(x: 0, y: 0, width: 800, height: 600),
                onClose: { },
                onCreateNext: { _ in }
            )
            .environmentObject(GraphModel())
        }
        .frame(width: 800, height: 600)
    }
}
#endif
