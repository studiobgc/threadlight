import SwiftUI

struct EditorToolbar: View {
    @EnvironmentObject var graphModel: GraphModel
    @Binding var showingPalette: Bool
    @Binding var showingProperties: Bool
    @Binding var isWritingMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section - File operations
            HStack(spacing: 2) {
                ToolbarButton(icon: "doc.badge.plus", tooltip: "New Graph") {
                    graphModel.newGraph()
                }
                
                ToolbarButton(icon: "folder", tooltip: "Open") {
                    // TODO: File picker
                }
                
                ToolbarButton(icon: "square.and.arrow.down", tooltip: "Save") {
                    // TODO: Save
                }
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                ToolbarButton(icon: "arrow.uturn.backward", tooltip: "Undo", disabled: !graphModel.canUndo) {
                    graphModel.undo()
                }
                
                ToolbarButton(icon: "arrow.uturn.forward", tooltip: "Redo", disabled: !graphModel.canRedo) {
                    graphModel.redo()
                }
            }
            
            Spacer()
            
            // Center section - Graph name
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(graphModel.graphInfo.name)
                    .font(DS.Font.bodyMedium)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Right section - View toggles
            HStack(spacing: 2) {
                // Writing mode - the key insight from Disco Elysium
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isWritingMode = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.line")
                        Text("Write")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.accent)
                    )
                }
                .buttonStyle(.plain)
                .help("Enter distraction-free writing mode")
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                ToolbarToggle(icon: "sidebar.left", tooltip: "Toggle Palette", isOn: $showingPalette)
                ToolbarToggle(icon: "sidebar.right", tooltip: "Toggle Properties", isOn: $showingProperties)
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                ToolbarButton(icon: "play.fill", tooltip: "Preview") {
                    // TODO: Preview mode
                }
                .foregroundColor(Color(hex: "4ade80"))
                
                ToolbarButton(icon: "gearshape", tooltip: "Settings") {
                    // TODO: Settings
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(DS.Colors.bg1)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var disabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(disabled ? .white.opacity(0.2) : .white.opacity(isHovered ? 0.9 : 0.6))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered && !disabled ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }
}

struct ToolbarToggle: View {
    let icon: String
    let tooltip: String
    @Binding var isOn: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isOn ? DS.Colors.accent : .white.opacity(isHovered ? 0.9 : 0.6))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? DS.Colors.accent.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }
}

// MARK: - Context Menu

struct NodeContextMenu: View {
    @EnvironmentObject var graphModel: GraphModel
    let node: DialogueNode
    
    var body: some View {
        Group {
            Button {
                graphModel.cloneNode(node.id)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .keyboardShortcut("d", modifiers: .command)
            
            Button {
                // TODO: Copy
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button {
                // TODO: Cut
            } label: {
                Label("Cut", systemImage: "scissors")
            }
            .keyboardShortcut("x", modifiers: .command)
            
            Divider()
            
            Button(role: .destructive) {
                graphModel.removeNode(node.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [])
        }
    }
}

struct CanvasContextMenu: View {
    @EnvironmentObject var graphModel: GraphModel
    let position: CGPoint
    
    var body: some View {
        Group {
            Menu("Add Node") {
                Button {
                    graphModel.addNode(type: .dialogue, at: position)
                } label: {
                    Label("Dialogue", systemImage: "bubble.left.fill")
                }
                
                Button {
                    graphModel.addNode(type: .dialogueFragment, at: position)
                } label: {
                    Label("Fragment", systemImage: "text.bubble.fill")
                }
                
                Button {
                    graphModel.addNode(type: .branch, at: position)
                } label: {
                    Label("Branch", systemImage: "arrow.triangle.branch")
                }
                
                Divider()
                
                Button {
                    graphModel.addNode(type: .condition, at: position)
                } label: {
                    Label("Condition", systemImage: "questionmark.diamond.fill")
                }
                
                Button {
                    graphModel.addNode(type: .instruction, at: position)
                } label: {
                    Label("Instruction", systemImage: "gearshape.fill")
                }
                
                Divider()
                
                Button {
                    graphModel.addNode(type: .hub, at: position)
                } label: {
                    Label("Hub", systemImage: "circle.hexagongrid.fill")
                }
                
                Button {
                    graphModel.addNode(type: .jump, at: position)
                } label: {
                    Label("Jump", systemImage: "arrow.uturn.right")
                }
            }
            
            Divider()
            
            Button {
                // TODO: Paste
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(true)
            
            Divider()
            
            Button {
                graphModel.clearSelection()
            } label: {
                Label("Select All", systemImage: "checkmark.square")
            }
            .keyboardShortcut("a", modifiers: .command)
        }
    }
}

#if DEBUG
struct Toolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EditorToolbar(showingPalette: .constant(true), showingProperties: .constant(true), isWritingMode: .constant(false))
                .environmentObject(GraphModel())
        }
        .frame(width: 1000)
        .background(Color(hex: "101012"))
    }
}
#endif
